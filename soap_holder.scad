include <round-anything/polyround.scad>
include <BOSL2/std.scad>

/* [Parts to display] */
// Number of fragments for circle rendering ($fn parameter)
fn = 10;
// Display the base with drainage slope
show_base = true;
// Display the outer walls
show_wall = true;
// Display the drainage grate with holes
show_grate = true;

/* [Base Dimensions] */
// Width of the soap holder (X-axis)
base_width = 100; // [500]
// Length of the soap holder (Y-axis, front-to-back)
base_length = 100; // [500]
// Height of the soap holder walls (Z-axis)
wall_height = 60; // [500]

// Height of the solid bottom layer
base_thickness = 10; // [20]

/* [Wall Properties] */
// Thickness of the walls
wall_thickness = 1.5; // [10]
// Fillet radius for rounded corners on the base
base_fillet_radius = 10; // [250]

// Can't use the [foo] [bar] syntax here because of makerworld.com parser

/* [Spout Outlet Hole] */
// Center height of the spout outlet hole from the base
drain_spout_outlet_height = 10; // [500]
// Diameter of the circular spout outlet hole
drain_spout_outlet_diameter = 10; // [100]
// Angle of the spout outlet coppo (tilt from vertical)
spout_outlet_angle = 22.5; // [45]
// Depth of the spout outlet coppo extension
spout_outlet_depth = 10; // [50]
// Width of the cutout in the spout outlet coppo
spout_outlet_cutout_width = 30; // [100]

/* [Drainage Grate] */
// Height offset from base where the drainage grate sits
grate_height_offset = 10; // [50]
// Thickness of the drainage grate
grate_thickness = 2; // [100]

/* [Drainage Hole Pattern] */
// Diameter of each drainage hole
hole_diameter = 3; // [10]
// Spacing between drainage holes
hole_spacing = 0.5; // [20]
// Minimum margin from grate edges to drainage holes
hole_margin = 2; // [20]

/* [Hidden] */
epsilon = 0.001;

$fn = fn;

// Calculated dimensions for inner area (inset by wall_thickness/2 on each side)
inner_width = base_width - wall_thickness;
inner_length = base_length - wall_thickness;
inner_fillet_radius = base_fillet_radius - wall_thickness / 2;

// Validation assertions
assert(base_fillet_radius <= min(base_width, base_length)/2, "Base fillet radius cannot exceed half the smaller base dimension");
assert(grate_height_offset <= wall_height, "Grate height offset cannot exceed wall height");
assert(base_thickness <= grate_height_offset, "Base thickness cannot exceed grate height offset");
// removed: assert on drain_spout_depth and drain_spout_fillet_radius (obsolete after removing wall opening)
assert(drain_spout_outlet_height >= 0 && drain_spout_outlet_height <= wall_height, "Spout outlet hole height must be within wall height");
assert(drain_spout_outlet_diameter > 0 && drain_spout_outlet_diameter <= inner_width, "Spout outlet hole diameter must be positive and fit within inner width");

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


module annulus(r_outer, r_inner, angle=360) {
    difference() {
        arc(r=r_outer, angle=angle, $fn=100);
        arc(r=r_inner, angle=angle, $fn=100);
    }
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


// removed: left_spout_border() helper (obsolete with enclosed wall design)

module base_rect(width, length, fillet_radius) {
    rect([width, length], rounding=fillet_radius);
}

module base_rect_inset(inner_width, inner_length, inner_fillet_radius) {
    // Inset base by wall_thickness/2 to align with wall centerline and ensure intersection
    rect([inner_width, inner_length], rounding=inner_fillet_radius);
}

module side_inclined_plane(channel_width, inner_width, inner_length, height_offset) {
    translate([channel_width/2, inner_length/2, 0])
        rotate([0, 0, 270])
            prism(inner_length, inner_width/2 - channel_width/2, height_offset);
}

module wall_perimeter(inner_width, inner_length, inner_fillet_radius, wall_thickness) {
    // Wall centerline is inset by wall_thickness/2 so the outer edge
    // aligns with the base dimensions
    right_path = turtle(
        [
            "move", inner_width/2 - inner_fillet_radius,
            "arcright", inner_fillet_radius, 90,
            "move", inner_length - inner_fillet_radius*2,
            "arcright", inner_fillet_radius, 90,
            "move", inner_width/2 - inner_fillet_radius
        ],
        [0, inner_length/2]
    );
    mirror_copy([1,0,0]) {
        bumpy_path(
            path=right_path,
            r_circle=wall_thickness/2
        );
    }
}

// Module: spout_outlet_coppo()
// Synopsis: Creates a decorative coppo (half-pipe) shape at the spout outlet.
// Description:
//   Creates a decorative tilted half-pipe extension at the water spout outlet.
//   The coppo is angled downward and has a cutout to guide water flow.
// Arguments:
//   wall_thickness = Thickness of the wall
//   spout_outlet_diameter = Diameter of the spout outlet hole
//   spout_outlet_angle = Angle of tilt from vertical (degrees)
//   spout_outlet_depth = Depth/length of the coppo extension
//   spout_outlet_cutout_width = Width of the cutout in the coppo
module spout_outlet_coppo(wall_thickness, spout_outlet_diameter, spout_outlet_angle, spout_outlet_depth, spout_outlet_cutout_width) {
    // Tilt the coppo downward from horizontal by the specified angle
    rotate([-90 + spout_outlet_angle, 0]) {
        // Position the coppo at the edge of the outlet hole and extend outward
        translate([0, spout_outlet_diameter/2, -spout_outlet_depth]) {
            difference() {
                // Create the half-pipe (180° annulus) by extruding along the depth
                linear_extrude(spout_outlet_depth) {
                    // Center the annulus at the outlet edge
                    translate([0, -spout_outlet_diameter/2, 0]) {
                        // Half-circle ring with wall thickness
                        annulus(
                            r_outer=spout_outlet_diameter/2,
                            r_inner=spout_outlet_diameter/2 - wall_thickness,
                            angle=180
                        );
                    }
                }

                // Cut out a section from the sides to create water flow guides
                translate([-spout_outlet_cutout_width/2, -spout_outlet_diameter/2, 0])
                rotate([90, 180, 90]) {
                    linear_extrude(spout_outlet_cutout_width) {
                        translate([-spout_outlet_diameter/2,  -spout_outlet_diameter/2, 0]) {
                            difference() {
                                // Start with a square in the corner
                                square(spout_outlet_diameter/2);
                                // Remove a 90° arc to create a rounded cutout edge
                                arc(
                                    r=spout_outlet_diameter/2,
                                    angle=90,
                                    wedge=true,
                                    $fn=100
                                );
                            }
                        }
                    }
                }
            }
        }
    }
}

module wall(wall_height, inner_width, inner_length, inner_fillet_radius, wall_thickness, spout_outlet_height, spout_outlet_diameter, spout_outlet_angle, spout_outlet_depth, spout_outlet_cutout_width) {
    difference() {
        linear_extrude(wall_height) {
            wall_perimeter(
                inner_width=inner_width,
                inner_length=inner_length,
                inner_fillet_radius=inner_fillet_radius,
                wall_thickness=wall_thickness
            );
        }
        
        // Create a round hole on the wall for the spout exit
        translate([0, -inner_length/2 + wall_thickness / 2 + epsilon, spout_outlet_height])
            rotate([90, 0, 0])
                linear_extrude(wall_thickness + 2*epsilon)
                    circle(r=spout_outlet_diameter/2, $fn=100);
    }

    // Decorative spout outlet coppo (half-pipe) shape
    translate([
        0, 
        -inner_length/2 + wall_thickness / 2, 
        spout_outlet_height 
    ]) {
        spout_outlet_coppo(
            wall_thickness=wall_thickness,
            spout_outlet_diameter=spout_outlet_diameter,
            spout_outlet_angle=spout_outlet_angle,
            spout_outlet_depth=spout_outlet_depth,
            spout_outlet_cutout_width=spout_outlet_cutout_width
        );
    }
    
}

module base(base_thickness, inner_width, inner_length, inner_fillet_radius, channel_width, grate_height_offset) {
    linear_extrude(base_thickness)
        base_rect_inset(
            inner_width=inner_width,
            inner_length=inner_length,
            inner_fillet_radius=inner_fillet_radius
        );
    
    // Add inclined planes to help water drain to the spout
    difference() {
        translate([0,0,base_thickness]) {
            // The inclined side planes
            mirror_copy([1,0,0])
                side_inclined_plane(
                    channel_width=channel_width,
                    inner_width=inner_width,
                    inner_length=inner_length,
                    height_offset=grate_height_offset
                );
            
            // The back inclined plane
            translate([-inner_width/2, -inner_length/2, 0])
                prism(inner_width, inner_length, grate_height_offset);
        }
        // Remove everything outside the inner area (leaving wall_thickness)
        linear_extrude(grate_height_offset * 10)
            difference() {  
                offset(50)
                    base_rect_inset(
                        inner_width=inner_width,
                        inner_length=inner_length,
                        inner_fillet_radius=inner_fillet_radius
                    );
                base_rect_inset(
                    inner_width=inner_width,
                    inner_length=inner_length,
                    inner_fillet_radius=inner_fillet_radius
                );
            }
    }
}

// Drainage hole - the repeating element in the drainage pattern
module drainage_hole(diameter, rotation, sides) {
    // Renders a hexagonal hole for the drainage grate
    rotate(rotation) circle(r=diameter/2, $fn=sides);
}

// Tiling pattern spacing helpers
// Returns [x_spacing, y_spacing, row_offset]

function hex_tiling_spacing(pitch) = 
    [pitch, pitch * sqrt(3)/2, pitch/2];

function square_tiling_spacing(pitch) = 
    [pitch, pitch, 0];

module tile_grid(pattern, pitch, width, length) {
    /*
        This module arranges tiles in a grid.
        
        Parameters:
        - pattern: "hex" for hexagonal (honeycomb) grid,
                   "square" for rectangular grid
        - pitch: center-to-center distance between tiles
        - width: total width of the area to fill
        - length: total length of the area to fill
    */
    // Get spacing based on pattern type
    echo(pitch=pitch);
    spacing_data = (pattern == "hex") 
        ? hex_tiling_spacing(pitch)
        : square_tiling_spacing(pitch);
    
    echo(spacing_data=spacing_data);
    
    x_sp = spacing_data[0];
    y_sp = spacing_data[1];
    row_offset = spacing_data[2];

    // Calculate number of columns and rows needed to cover the area
    cols = ceil(width / x_sp);
    rows = ceil(length / y_sp);

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

module drainage_grate(base_thickness, grate_height_offset, grate_thickness, width, length, wall_thickness, fillet_radius, hole_diameter, hole_spacing, hole_margin) {
    // Limit holes to the area within the minimum margin
    hole_area_width = width - wall_thickness*2 - hole_margin;
    hole_area_length = length - wall_thickness*2 - hole_margin;
    
    hole_pitch = hole_diameter + hole_spacing;

    // Drainage grate with hexagonal hole pattern
    translate([0,0,base_thickness + grate_height_offset])
        linear_extrude(grate_thickness)
            difference() {
                // Grate outer area
                rect([width - wall_thickness*2, length - wall_thickness*2], rounding=fillet_radius - wall_thickness);
                
                // Limit holes to the area within the minimum margin
                intersection() {
                    // Grate inner area for holes to fit within the margin
                    rect(
                        [hole_area_width, hole_area_length],
                        rounding=fillet_radius - wall_thickness
                    );
    
                    // The oversized hole pattern grid
                    tile_grid(
                        pattern="hex",
                        pitch=hole_pitch,
                        width=hole_area_width,
                        length=hole_area_length
                    ) {
                        // Hex drainage hole
                        drainage_hole(
                            diameter=hole_diameter,
                            rotation=90,
                            sides=6
                        );
                    }
                }
                
            }
}

module soap_holder(
    show_base, show_wall, show_grate,
    base_width, base_length, wall_height, base_thickness, wall_thickness, base_fillet_radius,
    drain_spout_outlet_height, drain_spout_outlet_diameter, spout_outlet_angle, spout_outlet_depth, spout_outlet_cutout_width,
    grate_height_offset, grate_thickness,
    hole_diameter, hole_spacing, hole_margin,
    inner_width, inner_length, inner_fillet_radius
) {
    if (show_base) 
        color("steelblue") base(
            base_thickness=base_thickness,
            inner_width=inner_width,
            inner_length=inner_length,
            inner_fillet_radius=inner_fillet_radius,
            channel_width=drain_spout_outlet_diameter,
            grate_height_offset=grate_height_offset
        );
    if (show_wall) 
        color("palevioletred") wall(
            wall_height=wall_height,
            inner_width=inner_width,
            inner_length=inner_length,
            inner_fillet_radius=inner_fillet_radius,
            wall_thickness=wall_thickness,
            spout_outlet_height=drain_spout_outlet_height,
            spout_outlet_diameter=drain_spout_outlet_diameter,
            spout_outlet_angle=spout_outlet_angle,
            spout_outlet_depth=spout_outlet_depth,
            spout_outlet_cutout_width=spout_outlet_cutout_width
        );
    if (show_grate) 
        color("lightgray") drainage_grate(
            base_thickness=base_thickness,
            grate_height_offset=grate_height_offset,
            grate_thickness=grate_thickness,
            width=base_width,
            length=base_length,
            wall_thickness=wall_thickness,
            fillet_radius=base_fillet_radius,
            hole_diameter=hole_diameter,
            hole_spacing=hole_spacing,
            hole_margin=hole_margin
        );
}

soap_holder(
    show_base=show_base,
    show_wall=show_wall,
    show_grate=show_grate,
    base_width=base_width,
    base_length=base_length,
    wall_height=wall_height,
    base_thickness=base_thickness,
    wall_thickness=wall_thickness,
    base_fillet_radius=base_fillet_radius,
    drain_spout_outlet_height=drain_spout_outlet_height,
    drain_spout_outlet_diameter=drain_spout_outlet_diameter,
    spout_outlet_angle=spout_outlet_angle,
    spout_outlet_depth=spout_outlet_depth,
    spout_outlet_cutout_width=spout_outlet_cutout_width,
    grate_height_offset=grate_height_offset,
    grate_thickness=grate_thickness,
    hole_diameter=hole_diameter,
    hole_spacing=hole_spacing,
    hole_margin=hole_margin,
    inner_width=inner_width,
    inner_length=inner_length,
    inner_fillet_radius=inner_fillet_radius
);