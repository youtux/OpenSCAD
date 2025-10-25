include <../libs/round-anything/polyround.scad>; // Include the Round-Anything library
include <../libs/BOSL2/std.scad>

$fn=100;

base_width = 170; // [500]
base_depth = 157; // [500]

spout_length = 2.5;
spout_opening_width = 20;

base_height = 60; // [200]
base_layer_height = 2;
epsilon = 0.001;

wall_thickness = 2; // [10]

fillet_radius = 50;

spout_rounding = wall_thickness / 5;

assert(0<= spout_rounding && spout_rounding <= wall_thickness, "Spout rounding must be between 0 and wall thickness");

assert(spout_length >= wall_thickness+spout_rounding, "Spout length must be greater than twice the wall thickness");

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

wall_perimeter();

// difference() {
//     linear_extrude(base_height){
//         base();
        
//     }
    
    
//     // now let's carve out the soap holder cavity
//     translate([0,0,base_layer_height])
//         linear_extrude(base_height-base_layer_height + epsilon)
//         offset(-wall_thickness)
//             base();
// }
