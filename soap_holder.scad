include <round-anything/polyround.scad>
include <BOSL2/std.scad>
include <BOSL2/turtle3d.scad>
include <BOSL2/skin.scad>

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

// Height of the drainage level (base thickness and spout center height)
drainage_height = 3; // [20]

/* [Wall Properties] */
// Thickness of the walls
wall_thickness = 1.5; // [10]
// Fillet radius for rounded corners on the base
base_fillet_radius = 10; // [250]

// Can't use the [foo] [bar] syntax here because of makerworld.com parser

/* [Drainage Spout] */
// Width of the drainage spout opening
drain_spout_width = 15; // [100]
// Initial height of the spout at the inlet (where it connects to the wall)
drain_spout_inlet_height = 10; // [100]
// Radius of the rounded corners at the bottom of the U-shape
drain_spout_radius = 2.5; // [50]
// Final height of the spout at the outlet (determines taper)
drain_spout_outlet_height = 5; // [100]
// Length the spout extends outward from the wall
drain_spout_depth = 9; // [50]
// Downward tilt angle in degrees (positive = tilts down)
drain_spout_lean_angle = 15; // [15]

/* [Drainage Grate] */
// Height offset from base where the drainage grate sits
grate_height_offset = 5; // [50]
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
assert(drainage_height <= wall_height, "Drainage height cannot exceed wall height");
assert(drainage_height >= 0, "Drainage height must be non-negative");
assert(grate_height_offset <= wall_height, "Grate height offset cannot exceed wall height");
assert(drainage_height <= grate_height_offset, "Drainage height cannot exceed grate height offset");
// removed: assert on drain_spout_depth and drain_spout_fillet_radius (obsolete after removing wall opening)
assert(drain_spout_width > 0 && drain_spout_width <= inner_width, "Spout width must be positive and fit within inner width");
assert(drain_spout_inlet_height > 0, "Spout inlet height must be positive");
assert(drain_spout_outlet_height > 0, "Spout outlet height must be positive");
assert(drain_spout_radius > 0, "Spout radius must be positive");
assert(drain_spout_depth > 0, "Spout depth must be positive");

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

function u_shape(width, height, radius, anchor=CENTER) =
    let(
        flat_width = width - radius*2,
        side_height = height - radius,
        // Calculate Y offset based on anchor point
        // BOTTOM: base of U at y=0, so start at y=height (shape extends down to y=0)
        // CENTER: middle of U at y=0, so start at y=height/2
        // TOP: top of U at y=0, so start at y=0 (shape extends up from y=0)
        y_offset = anchor == BOTTOM ? height :
                   anchor == CENTER ? height/2 :
                   anchor == TOP ? 0 :
                   height/2,  // default to CENTER if unknown
        start_pos = [-width/2, y_offset]
    )
    assert(width > 0, "U-channel width must be positive")
    assert(height > 0, "U-channel height must be positive")
    assert(radius > 0, "U-channel radius must be positive")
    assert(flat_width >= 0, "U-channel width must be at least twice the radius")
    assert(side_height >= 0, "U-channel height must be at least the radius")
    turtle(
        [
            "right", 90,
            "move", side_height,
            "arcleft", radius, 90,
            "move", flat_width,
            "arcleft", radius , 90,
            "move", side_height,
        ], 
        start_pos
    );

module u_channel(width, height, radius, thickness)
{   
    shape = u_shape(
            width=width,
            height=height,
            radius=radius
        );
    stroke(shape, width=thickness, endcaps="round");
}


// Module: drainage_spout()
// Synopsis: Creates a decorative water drainage spout that leans downward and tapers.
// Description:
//   Creates a U-shaped drainage channel (like a half-pipe or rain gutter) that extends outward
//   from a wall or surface. The spout is designed to guide water flow with two key features:
//   1. **Downward lean**: The channel tilts downward as it extends outward (for gravity drainage)
//   2. **Vertical taper**: The opening gradually reduces in height from back to front
//   
//   This creates an attractive, functional water spout similar to traditional roof gutters or
//   decorative gargoyle-style drainage features.
//
// Arguments:
//   width = The width of the spout opening (distance between the outer edges of the two vertical sides)
//   height = The initial height of the spout at the back/inlet (where it connects to the wall)
//   radius = The radius of the rounded corners at the bottom of the U-shape
//   thickness = The wall thickness of the spout
//   outlet_height = The final height of the spout at the front/outlet (end point). This determines the taper amount.
//   depth = The length the spout extends outward (along the Z-axis before transformation)
//   lean_angle = The downward tilt angle in degrees (positive = tilts down). Default: 0 (no lean)
//
// Example:
//   drainage_spout(
//       width=50,           // 50mm wide spout opening
//       height=25,          // Starts at 25mm tall at the inlet
//       radius=12.5,        // 12.5mm rounded bottom
//       thickness=2,        // 2mm wall thickness
//       outlet_height=12.5, // Ends at 12.5mm tall at the outlet (50% reduction)
//       depth=20,           // Extends 20mm outward
//       lean_angle=30       // Tilt down 30 degrees
//   );
module drainage_spout(width, height, radius, thickness, outlet_height, depth, lean_angle=0)
{
    // Create the inlet U-channel cross-section shape (centerline path)
    inlet_shape = u_shape(
        width=width,
        height=height,
        radius=radius,
        anchor=BOTTOM
    );
    
    // Create the outlet U-channel cross-section shape (centerline path)
    outlet_y_offset = -depth * tan(lean_angle);
    outlet_shape = move([0, outlet_y_offset], u_shape(
        width=width,
        height=outlet_height,
        radius=radius,
        anchor=BOTTOM
    ));
    
    // Use offset_stroke to get the boundary of the stroked path
    // For open paths with closed=false, this returns a single closed path forming a ring
    // deduplicate() removes duplicate points that turtle() may create at segment junctions
    // (offset_stroke will fail with "Path has repeated points" error otherwise)
    inlet_boundary = offset_stroke(deduplicate(inlet_shape), width=thickness, closed=false);
    outlet_boundary = offset_stroke(deduplicate(outlet_shape), width=thickness, closed=false);
    
    // Lift to 3D
    inlet_3d = path3d(inlet_boundary, 0);
    outlet_3d = path3d(outlet_boundary, depth);
    
    // TODO: Apply some rounding around the edges and the big edge
    skin([inlet_3d, outlet_3d], slices=0, caps=true, sampling="segment");
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
// Example:
//   my_path = arc(r=30, n=10, angle=90);
//   circles_on_path(my_path, r_circle=2);
module circles_on_path(path, r_circle) {
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
                circle(r=r_circle, $fn=$fn);
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
// Example:
//   my_path = arc(r=30, n=10, angle=90);
//   bumpy_path(my_path, r_circle=2);
module bumpy_path(path, r_circle) {
    // Draw circles at each point along the arc
    circles_on_path(path=path, r_circle=r_circle);

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

module wall(wall_height, inner_width, inner_length, inner_fillet_radius, wall_thickness, drainage_height, drain_spout_width, drain_spout_inlet_height, drain_spout_radius, drain_spout_outlet_height, drain_spout_depth, drain_spout_lean_angle) {
    difference() {
        linear_extrude(wall_height) {
            wall_perimeter(
                inner_width=inner_width,
                inner_length=inner_length,
                inner_fillet_radius=inner_fillet_radius,
                wall_thickness=wall_thickness
            );
        }

        // TODO: This can't be a cylinder anymore
        // because the spout is not a cylinder. We probably want to instead
        // make a convex hull of the spout inlet shape extruded through the wall thickness.
        
        // Create a round hole on the wall for the spout exit
        translate([0, -inner_length/2 + wall_thickness / 2 + epsilon, drainage_height])
            cyl(
                h=wall_thickness + 2*epsilon,
                r=drain_spout_width/2,
                anchor=BACK+TOP,
                orient=BACK,
                $fn=fn
            );}

    // Drainage spout extending from the wall
    translate([
        0, 
        -inner_length/2 + wall_thickness/2, 
        drainage_height
    ])
        rotate([90, 0, 0])
            drainage_spout(
                width=drain_spout_width,
                height=drain_spout_inlet_height,
                radius=drain_spout_radius,
                thickness=wall_thickness,
                outlet_height=drain_spout_outlet_height,
                depth=drain_spout_depth + wall_thickness/2,
                lean_angle=drain_spout_lean_angle
            );    
}

module base(drainage_height, inner_width, inner_length, inner_fillet_radius, channel_width, grate_height_offset) {
    linear_extrude(drainage_height)
        base_rect_inset(
            inner_width=inner_width,
            inner_length=inner_length,
            inner_fillet_radius=inner_fillet_radius
        );
    
    // Add inclined planes to help water drain to the spout
    difference() {
        translate([0,0,drainage_height]) {
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
    spacing_data = (pattern == "hex") 
        ? hex_tiling_spacing(pitch)
        : square_tiling_spacing(pitch);
    
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

module drainage_grate(drainage_height, grate_height_offset, grate_thickness, width, length, wall_thickness, fillet_radius, hole_diameter, hole_spacing, hole_margin) {
    // Limit holes to the area within the minimum margin
    hole_area_width = width - wall_thickness*2 - hole_margin;
    hole_area_length = length - wall_thickness*2 - hole_margin;
    
    hole_pitch = hole_diameter + hole_spacing;

    // Drainage grate with hexagonal hole pattern
    translate([0,0,drainage_height + grate_height_offset])
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
    base_width, base_length, wall_height, drainage_height, wall_thickness, base_fillet_radius,
    drain_spout_width, drain_spout_inlet_height, drain_spout_radius, drain_spout_outlet_height, drain_spout_depth, drain_spout_lean_angle,
    grate_height_offset, grate_thickness,
    hole_diameter, hole_spacing, hole_margin,
    inner_width, inner_length, inner_fillet_radius
) {
    if (show_base) 
        color("steelblue") base(
            drainage_height=drainage_height,
            inner_width=inner_width,
            inner_length=inner_length,
            inner_fillet_radius=inner_fillet_radius,
            channel_width=drain_spout_width,
            grate_height_offset=grate_height_offset
        );
    if (show_wall) 
        color("palevioletred") wall(
            wall_height=wall_height,
            inner_width=inner_width,
            inner_length=inner_length,
            inner_fillet_radius=inner_fillet_radius,
            wall_thickness=wall_thickness,
            drainage_height=drainage_height,
            drain_spout_width=drain_spout_width,
            drain_spout_inlet_height=drain_spout_inlet_height,
            drain_spout_radius=drain_spout_radius,
            drain_spout_outlet_height=drain_spout_outlet_height,
            drain_spout_depth=drain_spout_depth,
            drain_spout_lean_angle=drain_spout_lean_angle
        );
    if (show_grate) 
        color("lightgray") drainage_grate(
            drainage_height=drainage_height,
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
    drainage_height=drainage_height,
    wall_thickness=wall_thickness,
    base_fillet_radius=base_fillet_radius,
    drain_spout_width=drain_spout_width,
    drain_spout_inlet_height=drain_spout_inlet_height,
    drain_spout_radius=drain_spout_radius,
    drain_spout_outlet_height=drain_spout_outlet_height,
    drain_spout_depth=drain_spout_depth,
    drain_spout_lean_angle=drain_spout_lean_angle,
    grate_height_offset=grate_height_offset,
    grate_thickness=grate_thickness,
    hole_diameter=hole_diameter,
    hole_spacing=hole_spacing,
    hole_margin=hole_margin,
    inner_width=inner_width,
    inner_length=inner_length,
    inner_fillet_radius=inner_fillet_radius
);
