layer_height = 0.2;
min_layer_height = 0.07;
extrusion_width = 0.45;
extrusion_overlap = layer_height * (1 - PI/4);
extrusion_spacing = extrusion_width - extrusion_overlap;

// convert between path counts and spacing, qspace to quantize
function xspace(n=1) = n*extrusion_spacing;
function nspace(x=xspace()) = x/extrusion_spacing;
function qspace(x=xspace()) = xspace(round(nspace(x)));
function cspace(x=xspace()) = xspace(ceil(nspace(x)));
function fspace(x=xspace()) = xspace(floor(nspace(x)));

// convert between path counts and width, qspace to quantize
function xwall(n=1) = xspace(n) + (0<n ? extrusion_overlap : 0);
function nwall(x=xwall()) =  // first path gets full extrusion width
    x < 0 ? nspace(x) :
    x < extrusion_overlap ? 0 :
    nspace(x - extrusion_overlap);
function qwall(x=xwall()) = xwall(round(nwall(x)));
function cwall(x=xwall()) = xwall(ceil(nwall(x)));
function fwall(x=xwall()) = xwall(floor(nwall(x)));

// quantize thin walls only (less than n paths wide, default for 2 perimeters)
function qthin(x=xwall(), n=4.5) = x < xwall(n) ? qwall(x) : x;
function cthin(x=xwall(), n=4.5) = x < xwall(n) ? cwall(x) : x;
function fthin(x=xwall(), n=4.5) = x < xwall(n) ? fwall(x) : x;

// convert between layer counts and height, qlayer to quantize
function zlayer(n=1) = n*layer_height;
function nlayer(z=zlayer()) = z/layer_height;
// quantize heights
function qlayer(z=zlayer()) = zlayer(round(nlayer(z)));
function clayer(z=zlayer()) = zlayer(ceil(nlayer(z)));
function flayer(z=zlayer()) = zlayer(floor(nlayer(z)));

tolerance = 0.001;

$fa = 5;
$fs = min_layer_height / 2;  // avoid aliasing
// $fs = min(layer_height/2, xspace(1)/2);

inch = 25.4;
card = [2.5*inch, 3.5*inch];  // standard playing card dimensions

// seams add about 1/2mm to each dimension
sand_sleeve = [81, 122];  // Dixit
orange_sleeve = [73, 122];  // Tarot
magenta_sleeve = [72, 112];  // Scythe
brown_sleeve = [67, 103];  // 7 Wonders
lime_sleeve = [82, 82];  // Big Square
blue_sleeve = [73, 73];  // Square
dark_blue_sleeve = [53, 53];  // Mini Square
gray_sleeve = [66, 91];  // Standard Card
purple_sleeve = [62, 94];  // Standard European
ruby_sleeve = [46, 71];  // Mini European
green_sleeve = [59, 91];  // Standard American
yellow_sleeve = [44, 67];  // Mini American
catan_sleeve = [56, 82];  // Catan (English)

no_sleeve = 0.35;  // common unsleeved card thickness (UG assumes 0.325)
thin_sleeve = 0.1;  // 50 micron sleeves
thick_sleeve = 0.2;  // 100 micron sleeves
double_sleeve = thick_sleeve + thin_sleeve;
function double_sleeve_count(d) = floor(d / (no_sleeve + double_sleeve));
function thick_sleeve_count(d) = floor(d / (no_sleeve + thick_sleeve));
function thin_sleeve_count(d) = floor(d / (no_sleeve + thin_sleeve));
function unsleeved_count(d) = floor(d / no_sleeve);
function vdeck(n=1, sleeve=double_sleeve, card=yellow_sleeve) =
    [card[0], card[1], n*(no_sleeve+sleeve)];

function unit_axis(n) = [for (i=[0:1:2]) i==n ? 1 : 0];

floor0 = qlayer(inch/16);
wall0 = qwall(floor0);
gap0 = 0.1;

module raise(z=floor0) {
    translate([0, 0, z]) children();
}

module cbox(size, center=false) {
    linear_extrude(size[2], center=center)
        square([size[0], size[1]], center=true);
}

module bullnose_cube(size, r=floor0, center=false) {
    origin = [0, 0, center ? 0 : size[2]/2];
    c = size/2 - [r, r, r];
    translate(origin) hull() {
        cube([size[0], 2*c[1], 2*c[2]], center=true);
        cube([2*c[0], size[1], 2*c[2]], center=true);
        cube([2*c[0], 2*c[1], size[2]], center=true);
        for (x=[1, -1]) for (y=[1, -1]) for (z=[1, -1])
            translate([c[0]*x, c[1]*y, c[2]*z]) sphere(r);
    }
}

test_ext = [inch, inch/2, 2*inch];
test_int = test_ext - [2*3.3, 2*2.3, 2*floor0];

difference() {
    bullnose_cube([inch, inch/2, 2*inch], r=2);
    raise(4) cbox(2*test_ext);
    raise() cbox(test_int);
}


// TODO: old code, update or remove this
// common sleeve dimensions
FFG = [66.5, 0.2, 94];

// wall0 = xwall(3);
// gap0 = 0.1;
thick0 = 2*wall0 + gap0;
join0 = 10;
seam0 = 1/3;
rise0 = 1/3;

module beveler(size, flats=1, walls=1, center=false) {
    function unit_axis(n) = [for (i=[0:1:2]) i==n ? 1 : 0];
    module bevel(w, n=0) {
        a = unit_axis(n);
        v = [1, 1, 1] - a;
        aj = (n-1+3) % 3;
        ak = (n+1+3) % 3;
        for (j=[1,-1]) for (k=[1,-1]) {
            dj = j*unit_axis(aj)*size[aj]/2;
            dk = k*unit_axis(ak)*size[ak]/2;
            translate(origin+dj+dk)
                rotate(45*a) cube(a*(size[n]+10) + v*sqrt(2)*w, center=true);
        }
    }
    xy = sqrt(2) * flats;
    z = sqrt(2) * walls;
    origin = center ? [0, 0, 0] : size/2;
    bevel(flats, 0);
    bevel(flats, 1);
    bevel(walls, 2);
}

module beveled_cube(size, flats=1, walls=1, center=false) {
    difference() {
        cube(size, center);
        beveler(size=size, flats=flats, walls=walls, center=center);
    }
}

module rounded_cube(size, thick=thick0, walls=wall0, center=false) {
    R = max(thick, walls);
    B = min(thick, walls);
    L = B*sqrt(2)/2;
    S = R - sqrt(R*R - L*L);
    O = (R+L-S)*sqrt(2)/2;  // (R-S)*sqrt(2)/2;
    $fa = 6;
    module axis(x, y, z, a=[0, 0, 0]) {
        rotate(a)
        for (s0=[1,-1]) for (s1=[1,-1]) {
            // 1/2-step rotation aligns all the spheres & cylinders
            translate([s0*(x-O), s1*(y-O), 0])
                rotate($fa/2) cylinder(r=R, h=2*(z-O), center=true);
            if (a == [0, 0, 0])  // corners
                for (s2=[1,-1]) translate([s0*(x-O), s1*(y-O), s2*(z-O)])
                    rotate($fa/2) sphere(r=R);
        }
    }
    origin = center ? [0, 0, 0] : size/2;
    translate(origin) hull() intersection() {
        cube(size, center=true);
        union() {
            axis(size[0]/2, size[1]/2, size[2]/2);
            axis(size[2]/2, size[1]/2, size[0]/2, [0, 90, 0]);
            axis(size[0]/2, size[2]/2, size[1]/2, [90, 0, 0]);
        }
    }
}

// TODO: dividers
module deckbox(out=undef, in=undef, wall=wall0, gap=gap0, join=join0,
               seam=seam0, rise=rise0, rounded=true, lid=false, ghost=undef) {
    module side(w, d0, d1, h0, h1) {
        shape = [[0, 0], [0, h0+h1], [d0, h0+h1], [d0+d1, h0], [d0+d1, 0]];
        if (0<h1) rotate([90, 0, 90]) linear_extrude(w) polygon(shape);
        if (0<h0) cube([w, d0+d1+d0, h0]);
    }
    module snap(d, a=0) {
        jfit = join * cos(atan(z1/run));
        snaph = xspace(2);
        snapd = min(d, jfit-2*vgap-2*snaph);
        rotate([90, 0, a])
            cylinder(d1=snapd+2*snaph, d2=snapd, h=snaph, center=true);
    }
    module box(wall, join=0, inset=0) {
        space = join && inset ? vgap : 0;
        translate([inset, inset, 0])
            cube([box[0]-2*inset, wall, z0+z1+join-space]);  // back
        translate([inset, box[1]-wall-inset, 0])
            cube([box[0]-2*inset, wall, z0+join-space]);  // front
        difference() {
            for (x=[inset, box[0]-wall-inset]) translate([x, inset, 0])
                side(wall, thick-inset, run, z0+join-space, z1);
            if (join) {  // snap
                y = thick + 4/5*run;
                z = z0 + 1/5*z1 + join/2;
                translate([inset?inset:wall, y, z])
                    snap(join/4, inset?90:-90);
                translate([box[0]-(inset?inset:wall), y, z]) mirror([1, 0, 0])
                    snap(join/4, inset?90:-90);
            }
        }
        if (join) {  // snap
            y = thick + 1/5*run;
            z = z0 + 4/5*z1 + join/2;
            translate([inset?inset:wall, y, z]) mirror([1, 0, 0])
                snap(join/4, inset?90:-90);
            translate([box[0]-(inset?inset:wall), y, z])
                snap(join/4, inset?90:-90);
        }
    }

    vgap = max(gap, layer_height);
    flat = round(wall/layer_height) * layer_height;
    thick = 2*wall + gap;
    in0 = [thick, thick, flat];
    box = is_undef(out) ? in + 2*in0 : out;
    run = box[1]-2*thick;
    z1 = rise * (box[2] - join);
    z0 = (lid ? 1 - rise - seam : seam) * (box[2] - join);
    echo("exterior", box);
    echo("interior", box - 2*in0);
    echo("lid angle", z1, run, atan(z1/run));
    echo("double sleeve", double_sleeve_count(run));
    echo("thick sleeve", thick_sleeve_count(run));
    echo("thin sleeve", thin_sleeve_count(run));
    echo("unsleeved", unsleeved_count(run));

    // reference objects
    %if (ghost) translate([0, box[1], box[2]]) rotate([0, 180, 0])
        deckbox(out, in, wall, gap, join, seam, rise, lid=!lid, ghost=false);
    %if (ghost!=false) translate(in0) cube(box-2*in0);

    difference() {
        intersection() {
            if (lid) {
                cube([box[0], box[1], flat]);  // floor
                box(thick);  // wall
                box(wall, join);  // joint
            }
            else {
                inset = thick - wall;
                translate([inset, inset, 0])
                    cube([box[0]-2*inset, box[1]-2*inset, flat]);  // floor
                box(thick);  // wall
                box(wall, join, inset);  // joint
            }
            if (rounded) rounded_cube(box, thick, wall);
            else beveled_cube(box, thick, xspace(2));
        }
        translate([box[0]/2, 0, (z0+z1+(lid?join:0))/2])
            rotate([90, lid?180:0, 0])
            for (d=[0,1])
                linear_extrude(xspace(2-d), center=true)
                    offset(r=d*layer_height) children();
    }
}

module set(out=undef, in=undef, wall=wall0, gap=gap0, join=join0,
           seam=seam0, rise=rise0, rounded=true, ghost=undef) {
    flat = round(wall/layer_height) * layer_height;
    thick = 2*wall + gap;
    in0 = [thick, thick, flat];
    box = is_undef(out) ? in + 2*in0 : out;
    echo(box);
    echo(box-2*in0);
    translate([box[0]+10, 0, 0])
        deckbox(out=out, in=in, wall=wall, gap=gap, join=join,
                seam=seam, rise=rise, rounded=rounded, ghost=ghost) children();
    deckbox(out=out, in=in, wall=wall, gap=gap, join=join, seam=seam,
            rise=rise, rounded=rounded, lid=true, ghost=ghost) children();
}

module bevel_test(out, wall=wall0, gap=gap0, rounded=true) {
    box = [out[0], out[1], 2*out[2]];
    flat = round(wall/layer_height) * layer_height;
    difference() {
        deckbox(out=box, wall=wall, gap=gap, join=out[2]-flat,
                rounded=rounded, lid=true, ghost=false);
        translate([-1/2, -1/2, out[2]]) cube(box+[1,1,1]);
    }
}

Rocky30 = [75, 300/10, 98.5];
*deckbox(Rocky30, lid=true) {
    $fa=6;
    difference() {
        circle(d=45);
        circle(d=40);
    }
    text("B", font="Palatino Linotype", size=30,
         halign="center", valign="center");
}


// measurements (mm)

// total height: 98.5
// 100: 98.4, 98.5
// 80: 98.5, 98.6, 98.5, 98.6, 98.5
// 60: 98.5, 98.6
// 40: 98.6, 98.6

// lid width at seam
// 100: 75.9, 76.0
// 80: 75.9, 75.8, 75.8, 75.9, 76.0
// 60: 75.6, 75.5
// 40: 76.1, 76.2

// base width
// 100: 75.7, 75.7
// 80: 75.7, 75.6, 75.6, 75.7, 75.8
// 60: 75.5, 75.5
// 40: 76.0, 76.0

// lid depth
// 100: 74.8, 74.8
// 80: 60.0, 60.0, 60.0, 60.0, 60.0
// 60: 49.9, 49.9
// 40: 35.2, 35.2

// base depth
// 100: 74.6, 74.6
// 80: 60.0, 60.0, 60.0, 60.0, 60.1
// 60: 49.9, 49.8
// 40: 35.1, 35.2

// lid front height
// 100: 
// 80: 69.1, 69.2, 69.1, 69.2, 69.2
// 60: 
// 40: 

// lid rear height
// 100: 
// 80: 38.1, 38.1, 38.1, 38.1, 38.1
// 60: 
// 40: 

// lid thickness front wall
// 100: 
// 80: 2.2, 2.2, 2.2, 2.3, 2.3
// 60: 
// 40: 

// lid thickness front joint
// 100: 
// 80: 1.1, 1.1, 1.1, 1.1, 1.1
// 60: 
// 40: 

// lid thickness rear wall
// 100: 
// 80: 2.4, 2.4, 2.4, 2.4, 2.4
// 60: 
// 40: 

// lid thickness rear joint
// 100: 
// 80: 1.1, 1.0, 1.0, 1.0, 1.1
// 60: 
// 40: 

// lid thickness side wall
// 100: 
// 80: 3.4, 3.4, 3.4, 3.4, 3.4
// 60: 
// 40: 

// lid thickness side joint
// 100: 
// 80: 1.9, 1.9, 1.9, 1.9, 1.9
// 60: 
// 40: 

// base front height (top to table)
// 100: 
// 80: 38.3, 38.3, 38.3, 38.2, 38.3
// 60: 
// 40: 

// base front height (seam to table)
// 100: 
// 80: 29.4, 29.3, 29.4, 29.5, 29.5
// 60: 
// 40: 

// base rear height (top to table)
// 100: 
// 80: 69.6, 69.5, 69.7, 69.7, 69.7
// 60: 
// 40: 

// base rear height (seam to table)
// 100: 
// 80: 60.4, 60.4, 60.3, 60.4, 60.5
// 60: 
// 40: 

// base thickness front wall
// 100: 
// 80: 2.3, 2.3, 2.3, 2.3, 2.3
// 60: 
// 40: 

// base thickness front joint
// 100: 
// 80: 1.1, 1.1, 1.1, 1.1, 1.1
// 60: 
// 40: 

// base thickness rear wall
// 100: 
// 80: 2.2, 2.2, 2.2, 2.3, 2.4
// 60: 
// 40: 

// base thickness rear joint
// 100: 
// 80: 1.1, 1.1, 1.1, 1.1, 1.2
// 60: 
// 40: 

// base thickness side wall
// 100: 
// 80: 3.3, 3.3, 3.3, 3.3, 3.3
// 60: 
// 40: 

// base thickness side joint
// 100: 
// 80: 1.4, 1.4, 1.4, 1.4, 1.4
// 60: 
// 40: 

// large snap radius
// 100: 
// 80: 4.0, 4.0, 4.0, 4.0, 4.0
// 60: 
// 40: 

// large snap center to joint edge
// 100: 
// 80: 4.0, 4.0, 4.0. 3.9, 4.0
// 60: 
// 40: 

// large snap center to rear
// 100: 
// 80: 15.8, 15.8, 15.8, 15.8, 15.9
// 60: 
// 40: 

// XXX
// 100: 
// 80: 
// 60: 
// 40: 

// corner radius: 2
