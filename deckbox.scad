layer_height = 0.2;
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

tolerance = 0.001;
border = 1;

$fa = 6;
$fs = min(layer_height, xspace(1/2));

card = [2.5*25.4, 0.325, 3.5*25.4];  // standard playing card dimensions
double_sleeve = 0.3;
thick_sleeve = 0.2;
thin_sleeve = 0.1;
function double_sleeve_count(d) = floor(d / (card[1] + double_sleeve));
function thick_sleeve_count(d) = floor(d / (card[1] + thick_sleeve));
function thin_sleeve_count(d) = floor(d / (card[1] + thin_sleeve));
function unsleeved_count(d) = floor(d / card[1]);

function unit_axis(n) = [for (i=[0:1:2]) i==n ? 1 : 0];

// common sleeve dimensions
FFG = [66.5, 0.2, 94];

wall0 = xwall(3);
gap0 = 0.1;
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

module rounder(size, flats=1, walls=1, center=false) {
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

module rounded_cube(size, flats=1, walls=1, axis=undef, center=false) {
    if (is_undef(axis)) intersection() {
        intersection_for (a=[0:1:2])
            rounded_cube(axis=a,
                         size=size, flats=flats, walls=walls, center=center);
    }
    else {
        origin = center ? [0, 0, 0] : size/2;
        w = axis<2 ? flats : walls;
        a = unit_axis(axis);
        ac = [[0, 90, 0], [90, 0, 0], [0, 0, 0]];
        aj = (axis-1+3) % 3;
        ak = (axis+1+3) % 3;
        translate(origin) {
            wj0 = unit_axis(aj)*size[aj];
            wj1 = unit_axis(aj)*(size[aj]-2*w);
            wk0 = unit_axis(ak)*size[ak];
            wk1 = unit_axis(ak)*(size[ak]-2*w);
            hull() {
                cube(a*size[axis] + wj0 + wk1, center=true);
                cube(a*size[axis] + wj1 + wk0, center=true);
                for (j=[1,-1]) for (k=[1,-1]) {
                    translate(j*wj1/2+k*wk1/2) rotate(ac[axis])
                        rotate(15)
                        cylinder(r=w, h=size[axis], center=true, $fa=30);
                }
            }
        }
    }
}

// TODO: dividers
// TODO: logos & labels
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
    echo("double sleeve", double_sleeve_count(box[1]));
    echo("thick sleeve", thick_sleeve_count(box[1]));
    echo("thin sleeve", thin_sleeve_count(box[1]));
    echo("unsleeved", unsleeved_count(box[1]));

    // reference objects
    %if (ghost) translate([0, box[1], box[2]]) rotate([0, 180, 0])
        deckbox(out, in, wall, gap, join, seam, rise, lid=!lid, ghost=false);
    %if (ghost!=false) translate(in0) cube(box-2*in0);

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
                seam=seam, rise=rise, rounded=rounded, ghost=ghost);
    deckbox(out=out, in=in, wall=wall, gap=gap, join=join,
            seam=seam, rise=rise, rounded=rounded, lid=true, ghost=ghost);
}

// commercial box sizes
Boulder100int = [68.5, 67.5, 93];
Boulder80int = [68.5, 55, 93];
Boulder60int = [68.5, 46.5, 93];
Boulder40int = [68.5, 30, 93];
Boulder100ext = [76, 75, 93];
Boulder80ext = [76, 60, 98.5];
Boulder60ext = [76, 49.9, 98.5];
Boulder40ext = [76, 35, 98.5];

Rocky75 = [75, 300/4, 98.5];
Rocky60 = [75, 300/5, 98.5];
Rocky50 = [75, 300/6, 98.5];
Rocky37 = [75, 300/8, 98.5];
Rocky33 = [75, 300/9, 98.5];
Rocky30 = [75, 300/10, 98.5];
Rocky25 = [75, 300/12, 98.5];

*deckbox(Rocky, ghost=false);
*deckbox(Rocky, lid=true, ghost=false);
*deckbox(in=Boulder80, ghost=true);
*deckbox(in=Boulder80, lid=true);

*set([25, 40*.6, 60], seam=0.2, rise=0.6);
*set([25, 25, 25], seam=0.1, rise=0.8);

set(Rocky30);
*deckbox(Rocky30);
*deckbox(Rocky30, lid=true);
