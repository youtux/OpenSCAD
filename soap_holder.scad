include <round-anything/polyround.scad>; // Include the Round-Anything library
include <BOSL2/std.scad>

/* [Parts to display] */
// Number of fragments for circle rendering ($fn parameter)
fn=10;
// Display the base with drainage slope
show_base = true;
// Display the outer walls
show_wall = true;
// Display the drainage plate with holes
show_plate = true;

/* [Base] */
// Width of the soap holder
base_width = 100; // [500]
// Depth (front-to-back) of the soap holder
base_depth = 100; // [500]
// Total height of the soap holder walls
base_height = 60; // [500]

/* TODO: Maybe this can be deleted */
// Height of the solid bottom layer
base_layer_height = 2; // [20]

// Thickness of the walls
wall_thickness = 1.5; // [10]
// Radius of the rounded corners on the base
wall_fillet_radius = 10; // [250]

// Can't use the [foo] [bar] syntax here because of makerworld.com parser
/* [Drainage spout] */
// Width of the front drainage opening
spout_opening_width = 20; // [100]
// Radius of the rounded corners on the spout
spout_fillet_radius = 2; // [100]
// How far the spout extends forward from the base
spout_depth = 4; // [50]

/* [Drainage Plate] */
// Height from the base where the drainage plate sits
drainage_plate_offset = 10; // [50]
// Thickness of the drainage plate
plate_height = 2; // [100]

/* [Drainage Plate Pattern] */
// Size of each drainage hole
tile_size = 3; // [10]
// Gap between drainage holes
tile_gap = 0.5; // [20]
// Minimum margin from edges to drainage holes
tile_min_margin = 2; // [20]

/* [Hidden] */
epsilon = 0.001;

$fn = fn;

// Calculated dimensions for base inner area (inset by wall_thickness/2 on each side)
base_inner_width = base_width - wall_thickness;
base_inner_depth = base_depth - wall_thickness;
base_inner_fillet = wall_fillet_radius - wall_thickness / 2;

// Asserts must go after the variables,
// as makerworld.com won't be able to parse the variable
// definitions if they are after the asserts.
assert(wall_fillet_radius <= min(base_width, base_depth)/2, "Wall fillet radius can't be greater than half the smaller base dimension");
assert(drainage_plate_offset <= base_height, "Drainage height can't be greater than base height");
assert(base_layer_height <= drainage_plate_offset, "Base layer height can't be greater than drainage height");
assert(spout_depth >= wall_thickness + spout_fillet_radius, "Spout depth must be greater than twice the wall thickness");

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


// Module: circles_on_path()
// Synopsis: Places circles continuously along a path at regular intervals.
// Description:
//   Places circles at regular intervals along an arbitrary path. The circles are spaced
//   such that they are touching each other (spacing = 2 * r_circle). This works for any
//   path shape (arcs, curves, spirals, etc.), as long as the path is continuous.
//   The function automatically calculates the total path length and distributes circles
//   evenly along the entire length.
// Arguments:
//   path = The path to place circles on. A list of 2D points.
//   r_circle = Radius of each circle. Default: 1
//   circle_fn = Number of fragments for circle rendering ($fn parameter). Default: 50
// Example:
//   my_path = arc(r=30, n=10, angle=90);
//   circles_on_path(my_path, r_circle=2, circle_fn=30);
module circles_on_path(path, r_circle, circle_fn=50) {
    // Generate cut distances spaced by 2*r_circle along the path
    path_length = path_length(path);
    n_cuts = floor(path_length / (2*r_circle));
    cutdists = [for (i = [0:n_cuts]) i * 2*r_circle];
    
    // Get points at those distances
    cuts = path_cut_points(path, cutdists, closed=false);
    // Extract just the points (first element of each cut)
    for (cut = cuts) {
        if (cut != undef) {
            translate(cut[0]){
                circle(r=r_circle, $fn=circle_fn);
            }
        }
    }
}

// Module: bumpy_path()
// Synopsis: Creates a bumpy/studded ring along an arbitrary path.
// Description:
//   Combines circles and a ring to create a bumpy, studded appearance along any arbitrary path.
//   This module draws circles at regular intervals along the path (creating the "bumps") and
//   also draws a ring-shaped region on the inside edge of the path with a width equal to r_circle.
//   The ring is created by offsetting the path inward and creating a region between the outer
//   and inner offset paths. This approach works for any path shape, not just arcs.
// Arguments:
//   path = The path to create the bumpy ring on. A list of 2D points.
//   r_circle = Radius of each circle/bump. The circles are spaced at intervals of 2*r_circle, and the ring width equals r_circle.
//   circle_fn = Number of fragments for circle rendering ($fn parameter). Default: 50
// Example:
//   my_path = arc(r=30, n=10, angle=90);
//   bumpy_path(my_path, r_circle=2, circle_fn=30);
module bumpy_path(path, r_circle, circle_fn=50) {
    // Draw circles at each point along the arc
    circles_on_path(path=path, r_circle=r_circle, circle_fn=circle_fn);

    // Draw ring on the inside using path offsets
    // Ring width equals r_circle
    inner_path = offset(path, delta=-r_circle, closed=false);
    // Create ring by combining inner path forward and outer path backward
    ring_path = concat(inner_path, reverse(path));
    region([ring_path]);
}


module left_spout_border() {
    translate([-wall_thickness, -wall_thickness])
        ring(32,r=wall_thickness, ring_width=wall_thickness, angle=90);
    translate([0, -wall_thickness])
        rect(
            [wall_thickness, spout_depth - wall_thickness],
            anchor=TOP+LEFT,
            rounding=[0,0,spout_fillet_radius,spout_fillet_radius]
        );
}

module base_rect() {
    rect([base_width, base_depth], rounding=wall_fillet_radius);
}

module base_rect_inset() {
    // Inset base by wall_thickness/2 to align with wall centerline and ensure intersection
    rect([base_inner_width, base_inner_depth], rounding=base_inner_fillet);
}

module side_inclined_plane() {
    translate([spout_opening_width/2, base_inner_depth/2, 0])
        rotate([0, 0, 270])
            prism(base_inner_depth, base_inner_width/2 - spout_opening_width/2, drainage_plate_offset);
}

module wall_perimeter() {
    // Wall centerline is inset by wall_thickness/2 so the outer edge
    // aligns with the base dimensions
    right_path = turtle(
        [
            "move", base_inner_width/2 - base_inner_fillet,
            "arcright", base_inner_fillet, 90,
            "move", base_inner_depth - base_inner_fillet*2,
            "arcright", base_inner_fillet, 90,
            "move", base_inner_width/2 - base_inner_fillet - spout_opening_width/2 - spout_fillet_radius,
            "arcleft", spout_fillet_radius, 90,
            "move", spout_depth - spout_fillet_radius - wall_thickness/2,
        ],
        [0, base_inner_depth/2]
    );
    mirror_copy([1,0,0])
    bumpy_path(
        path=right_path,
        r_circle=wall_thickness/2
    );
}

module wall() {
    linear_extrude(base_height)
        wall_perimeter();
}

module base() {
    linear_extrude(base_layer_height)
        base_rect_inset();
    
    // Add an inclined plane that will help the water drain to the spout
    difference() {
        translate([0,0,base_layer_height]) {
            // The inclined side planes
            mirror_copy([1,0,0])
                side_inclined_plane();
            
            // The back inclined plane
            translate([-base_inner_width/2, -base_inner_depth/2, 0])
                prism(base_inner_width, base_inner_depth, drainage_plate_offset);
        }
        // Remove everything outside the inner area (leaving wall_thickness)
        linear_extrude(drainage_plate_offset * 10)
            difference() {  
                offset(50)
                    base_rect_inset();
                base_rect_inset();
            }
    }
}

// drainage tile - the repeating element in the drainage pattern
module drainage_tile(size) {
    // Renders the basic geometric element that gets repeated in the tiling pattern
    rotate(90) circle(r=size/2, $fn=6);
}

// Tiling pattern spacing helpers
// Returns [x_spacing, y_spacing, row_offset]

function hex_tiling_spacing(pitch) = 
    [pitch, pitch * sqrt(3)/2, pitch/2];

function square_tiling_spacing(pitch) = 
    [pitch, pitch, 0];

module tile_grid(pattern, pitch, cols, rows) {
    /*
        This module arranges tiles in a grid.
        
        Parameters:
        - pattern: "hex" for hexagonal (honeycomb) grid,
                   "square" for rectangular grid
        - pitch: center-to-center distance between tiles
        - cols: number of columns in the grid
        - rows: number of rows in the grid
    */
    // Get spacing based on pattern type
    spacing_data = (pattern == "hex") 
        ? hex_tiling_spacing(pitch)
        : square_tiling_spacing(pitch);
    
    x_sp = spacing_data[0];
    y_sp = spacing_data[1];
    row_offset = spacing_data[2];

    total_width = (cols - 1) * x_sp;
    total_height = (rows - 1) * y_sp;

    for (j = [0 : rows - 1]) {
        y = -total_height/2 + j * y_sp;
        for (i = [0 : cols - 1]) {
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
    translate([0,0,base_layer_height + drainage_plate_offset])
        linear_extrude(plate_height)
            difference() {
                rect([base_width - wall_thickness*2, base_depth - wall_thickness*2], rounding=wall_fillet_radius - wall_thickness);
                
                intersection() {
                     // Limit holes to the area within the min margin
                    rect(
                        [base_width - wall_thickness*2 - tile_min_margin,
                        base_depth - wall_thickness*2 - tile_min_margin],
                        rounding=wall_fillet_radius - wall_thickness);
                    
                    tile_pitch = tile_size + tile_gap;    
                    tile_grid(
                        pattern="hex",
                        pitch=tile_pitch, 
                        cols=ceil(base_width / tile_pitch) + 2,
                        rows=ceil(base_depth / tile_pitch) + 2)
                        drainage_tile(size=tile_size);
                }
                
            }
}

module soap_holder() {
    if (show_base) 
        color("steelblue") base();
    if (show_wall) 
        color("palevioletred") wall();
    if (show_plate) 
        color("lightgray") plate();
}

soap_holder();