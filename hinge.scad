$fn=50;

pivot_radius = 5;
base_thickness = 3;
base_width = 15;

hinge_length = 30;

pin_radius = 2;
pin_taper = 0.25;

clearance = 0.2;

hinge_half_extrude_length = hinge_length/2-clearance/2;

mountingHoleRadius = 1.5;
mountingHoleEdgeOffset = 4;
mountingHoleCount = 3;
mountingHoleMoveIncrement=(hinge_length-2*mountingHoleEdgeOffset) / (mountingHoleCount-1);



module fillet(radius) {
    offset(radius) offset(-2*radius) offset(radius) children();
}

module hingeBaseProfile() {
  translate([pivot_radius,0,0]){
    square([base_width, base_thickness]);
  }
}


module pin(rotateY, radiusOffset) {
  translate([0,pivot_radius,hinge_half_extrude_length]){
    rotate([0,rotateY,0]){
      cylinder(h=hinge_length/2+clearance/2, r1=pin_radius+radiusOffset, r2=pin_radius+pin_taper+radiusOffset);
    }
  }
}

module hingeBodyHalf() {
    difference() {
        union() {
            linear_extrude(height=hinge_half_extrude_length){
                fillet(1) {
                    translate([0,pivot_radius,0]) {
                        circle(pivot_radius);
                    }
                    square([pivot_radius,pivot_radius]);
                    hingeBaseProfile();
                }
            }
            linear_extrude(hinge_length){
                fillet(1) hingeBaseProfile();
            }
            
        }
        plateHoles();
    }
    
}

module plateHoles() {
    for(increment=[0:mountingHoleCount-1]){
        echo("increment is currently", increment);
        translate([base_width/2+pivot_radius,-base_thickness,increment*mountingHoleMoveIncrement + mountingHoleEdgeOffset]){
            rotate([-90,0,0]){
                cylinder(r=mountingHoleRadius,h=base_thickness*4);
            }
        }
    }
}

module hingeHalfFemale() {
    difference() {
        hingeBodyHalf();
        pin(rotateY=180, radiusOffset=clearance);
    }
}

module hingeHalfMale() {
    translate([0,0,hinge_length])
        rotate([0,180,0]) {
            hingeBodyHalf();
            pin(rotateY=0, radiusOffset=0);
        }
}

hingeHalfFemale();
hingeHalfMale();
