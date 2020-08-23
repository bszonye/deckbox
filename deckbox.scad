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

wall0 = xwall(3);
gap0 = 0.1;
join0 = 10;
seam0 = 1/3;
rise0 = 1/3;

// TODO: dividers
// TODO: logos & labels
module deckbox(out=undef, in=undef, wall=wall0, gap=gap0, join=join0,
               seam=seam0, rise=rise0, lid=false, ghost=undef) {
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
    module bevel(b=1) {
        translate([box[0]/2, 0, 0]) rotate([45, 0, 0])
            cube([box[0]+1, b, b], center=true);
        translate([box[0]/2, box[1], 0]) rotate([45, 0, 0])
            cube([box[0]+1, b, b], center=true);
        translate([0, box[1]/2, 0]) rotate([0, 45, 0])
            cube([b, box[1]+1, b], center=true);
        translate([box[0], box[1]/2, 0]) rotate([0, 45, 0])
            cube([b, box[1]+1, b], center=true);
    }

    vgap = max(gap, layer_height);
    thick = 2*wall + gap;
    in0 = [thick, thick, wall];
    box = is_undef(out) ? in + 2*in0 : out;
    run = box[1]-2*thick;
    z1 = rise * (box[2] - join);
    z0 = (lid ? 1 - rise - seam : seam) * (box[2] - join);
    echo(z1, run, atan(z1/run));

    // reference objects
    %if (ghost) translate([0, box[1], box[2]]) rotate([0, 180, 0])
        deckbox(out, in, wall, gap, join, seam, rise, lid=!lid, ghost=false);
    %if (ghost!=false) translate(in0) cube(box-2*in0);

    difference() {
        if (lid) {
            cube([box[0], box[1], wall]);  // floor
            box(thick);  // wall
            box(wall, join);  // joint
        }
        else {
            inset = thick - wall;
            translate([inset, inset, 0])
                cube([box[0]-2*inset, box[1]-2*inset, wall]);  // floor
            box(thick);  // wall
            box(wall, join, inset);  // joint
        }
        bevel(wall*sqrt(2));
    }
}

module set(out=undef, in=undef, wall=wall0, gap=gap0, join=join0,
           seam=seam0, rise=rise0, ghost=undef) {
    thick = 2*wall+gap;
    in0 = [thick, thick, wall];
    box = is_undef(out) ? in + 2*in0 : out;
    echo(box);
    echo(box-2*in0);
    translate([box[0]+10, 0, 0])
        deckbox(out=out, in=in, wall=wall, gap=gap, join=join,
                seam=seam, rise=rise, ghost=ghost);
    deckbox(out=out, in=in, wall=wall, gap=gap, join=join,
            seam=seam, rise=rise, lid=true, ghost=ghost);
}

Boulder80 = [68.5, 55, 93];
Boulder100 = [68.5, 67.5, 93];
FFG = [66.5, 0.6, 94];

Test = [10, 10, 15];
Rocky = [75, 60, 100];
Warcry = [75, 40*0.6, 100];

*set(in=Test, seam=0, rise=1);
*deckbox(Rocky, ghost=false);
*deckbox(Rocky, lid=true, ghost=false);
*deckbox(in=Boulder80, ghost=true);
*deckbox(in=Boulder80, lid=true);

*set(Rocky, ghost=false);
*set(Warcry, ghost=false);
set([25, 40*.6, 60], seam=0.2, rise=0.6);
*set([25, 25, 25], seam=0.1, rise=0.8);
