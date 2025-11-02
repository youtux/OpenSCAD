include <../libs/round-anything/polyround.scad>; // Include the Round-Anything library
include <../libs/BOSL2/std.scad>
include <hex-grid.scad>

$fn=10;
epsilon = 0.001;

base_width = 100; // [500]
base_depth = 100; // [500]
base_height = 60; // [500]

plate_height = 2;


drainage_height = 10;

pattern_unit_size = 5;
pattern_spacing = 1;
pattern_min_margin = 2;

spout_length = 2.5;
spout_opening_width = 20;

base_layer_height = 2;
assert(base_layer_height <= drainage_height && drainage_height <= base_height, "Drainage height must be between 0 and base height");

wall_thickness = 2; // [10]

fillet_radius = 10;

spout_rounding = wall_thickness / 5;

assert(0<= spout_rounding && spout_rounding <= wall_thickness, "Spout rounding must be between 0 and wall thickness");
assert(spout_length >= wall_thickness+spout_rounding, "Spout length must be greater than twice the wall thickness");

module prism(l, w, h) {
    polyhedron(
        // pt      0        1        2        3        4        5
        points=[[0,0,0], [0,w,h], [l,w,h], [l,0,0], [0,w,0], [l,w,0]],
        // top sloping face (A)
        faces=[[0,1,2,3],
        // vertical rectangular face (B)
        [2,1,4,5],
        // bottom face (C)
        [0,3,5,4],
        // rear triangular face (D)
        [0,4,1],
        // front triangular face (E)
        [3,2,5]],
        convexity=5
    );
}

module left_spout_border() {
    translate([-wall_thickness, -wall_thickness])
        ring(32,r=wall_thickness, ring_width=wall_thickness, angle=90);
    translate([0, -wall_thickness])
        rect(
            [wall_thickness, spout_length - wall_thickness],
            anchor=TOP+LEFT,
            rounding=[0,0,spout_rounding,spout_rounding]
        );
}

module base_rect () {
    rect([base_width, base_depth], rounding=fillet_radius);
}

module side_inclined_plane() {
    translate([spout_opening_width/2,base_depth/2,0])
                rotate([0, 0, 270])
                    prism(base_depth, base_width/2 - spout_opening_width/2, drainage_height);
}

module wall_perimeter() { 
    difference(){
        base_rect();

        offset(-wall_thickness)   
            base_rect();
        
        // The opening for the spout
        translate([0,-base_depth/2])
            rect([spout_opening_width + (wall_thickness*4), wall_thickness], anchor=BOTTOM);
    }
        // the spout borders
    mirror_copy([1,0,0])
        translate([-(wall_thickness+spout_opening_width/2), -base_depth/2])
            left_spout_border();
}

module wall() {
    linear_extrude(base_height)
        wall_perimeter();
}

module base() {
    linear_extrude(base_layer_height)
        base_rect();
    
    // let's add an inclined plane that will help the water drain to the spout
    // we will want to use a polyhedron for this
    // we basically want an upside-down pyramid (apex at top, base at bottom)

    bottom_left = [-base_width/2, -base_depth/2, 0];
    up_left = [-base_width/2, base_depth/2, 0];
    up_right = [base_width/2, base_depth/2, 0];
    bottom_right = [base_width/2, -base_depth/2, 0];
        

    difference() {
        // TODO: Not the best looking, but for now it can do
        translate([0,0,base_layer_height]) {
            // The inclined side planes
            mirror_copy([1,0,0])
                side_inclined_plane();
            
            // the back inclined plane
            translate([-base_width/2,-base_depth/2,0])
                    prism(base_width, base_depth, drainage_height);
        }
        // Remove everything outside the inner area (leaving wall_thickness)
        linear_extrude(drainage_height *10)
            difference() {  
                offset(50)
                    base_rect();
                base_rect();
            }
    }
}

// drainage hole pattern
module drainage_hole_pattern(size) {
    // Create a regular polygon as a 2D shape, inscribed in a circle of diameter 'size'
    // sides parameter defines the number of sides (3=triangle, 4=square, 6=hexagon, etc.)
    circle(r=size/2);
}

// Tiling pattern spacing helpers
// Returns [x_spacing, y_spacing, row_offset]

function hex_tiling_spacing(unit_size, spacing) = 
    let(x = unit_size + spacing)
    [x, x * sqrt(3)/2, x/2];

function square_tiling_spacing(unit_size, spacing) = 
    let(x = unit_size + spacing)
    [x, x, 0];

module create_hole_pattern(pattern="hex") {
    /*
        This module arranges pattern units (holes) in a grid.
        
        Parameters:
        - pattern: "hex" for hexagonal (honeycomb) grid,
                   "square" for rectangular grid
    */
    plate_width = base_width - wall_thickness*2;
    plate_depth = base_depth - wall_thickness*2;

    // Get spacing based on pattern type
    spacing = (pattern == "hex") 
        ? hex_tiling_spacing(pattern_unit_size, pattern_spacing)
        : square_tiling_spacing(pattern_unit_size, pattern_spacing);
    
    x_sp = spacing[0];
    y_sp = spacing[1];
    row_offset = spacing[2];

    // Compute max number of holes that fit inside the plate with margin
    pattern_cols = floor((plate_width - pattern_min_margin*2 + pattern_spacing) / x_sp);
    pattern_rows = floor((plate_depth - pattern_min_margin*2 + pattern_spacing) / y_sp);

    total_width = (pattern_cols - 1) * x_sp;
    total_height = (pattern_rows - 1) * y_sp;

    for (j = [0 : pattern_rows - 1]) {
        y = -total_height/2 + j * y_sp;
        for (i = [0 : pattern_cols - 1]) {
            // Apply row offset to alternating rows
            x_offset = (j % 2 == 1) ? row_offset : 0;
            x = -total_width/2 + i * x_sp + x_offset;
            translate([x, y, 0]) {
                children();
            }
        }
    }
}

module plate() {
    // A simple plate with rounded corners
    
    linear_extrude(plate_height)
        translate([0,0,base_layer_height + drainage_height])
            difference() {
                rect([base_width - wall_thickness*2, base_depth - wall_thickness*2], rounding=fillet_radius - wall_thickness);
                
                intersection() {
                     // Limit holes to the area within the min margin
                    rect(
                        [base_width - wall_thickness*2 - pattern_min_margin,
                        base_depth - wall_thickness*2 - pattern_min_margin],
                        rounding=fillet_radius - wall_thickness);
                    
                    create_hole_pattern("hex")
                        drainage_hole_pattern(size=pattern_unit_size);
                }
                
            }
}

module soap_holder() {
    // color("#4682B4") 
    //     base();
    // color("palevioletred")
    //     wall();
    // color("lightgray")
        plate();
    // create_hole_pattern("hex")
    //     drainage_hole_pattern(size=pattern_unit_size);

}

soap_holder();