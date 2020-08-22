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
gap0 = 0.05;
join0 = 10;
seam0 = 0.33;
rise0 = 0.33;

// TODO: dividers
// TODO: logos & labels
// TODO: snap fit
module deckbox(in, wall=wall0, gap=gap0, join=join0, seam=seam0, rise=rise0,
               lid=false, ghost=undef) {
    module side(w, d0, d1, h0, h1) {
        shape = [[0, 0], [0, h0], [d0, h0],
                 [d0+d1, h0+h1], [d0+d1+d0, h0+h1], [d0+d1+d0, 0]];
        rotate([90, 0, 90]) linear_extrude(w) polygon(shape);
    }
    module box(wall, z0, inset=0) {
        translate([inset, inset, 0])
            cube([out[0]-2*inset, wall, z0]);  // front
        translate([inset, out[1]-wall-inset, 0])
            cube([out[0]-2*inset, wall, z0+z1]);  // back
        for (x=[inset, out[0]-wall-inset]) translate([x, inset, 0])
            side(wall, thick-inset, in[1], z0, z1);
    }

    thick = 2*wall + gap;
    in0 = [thick, thick, wall];
    out = in + 2 * in0;
    z1 = rise * (in[2] - join);
    z0 = wall + (lid ? 1 - rise - seam : seam) * (in[2] - join);

    // reference objects
    %if (ghost) translate([0, out[1], out[2]]) rotate([0, 180, 0])
        deckbox(in, wall, gap, join, seam, rise, lid=!lid, ghost=false);
    %if (ghost!=false) translate(in0) cube(in);

    if (lid) translate([out[0], out[1], 0]) rotate(180) {
        cube([out[0], out[1], wall]);  // floor
        box(thick, z0);  // wall
        box(wall, z0+join);  // joint
    }
    else {
        cube([out[0], out[1], wall]);  // floor
        box(thick, z0);  // wall
        space = max(gap, layer_height);
        box(wall, z0+join-space, thick-wall);  // joint
    }
}

module set(in, wall=wall0, gap=gap0, join=join0, seam=seam0, rise=rise0) {
    thick = 2*wall+gap;
    translate([in[0]+2*thick+10, 0, 0])
        deckbox(in, wall=wall, gap=gap, join=join, seam=seam, rise=rise);
    deckbox(in, wall=wall, gap=gap, join=join, seam=seam, rise=rise, lid=true);
}

Boulder = [68.5, 67.5, 93];
FFG = [66.5, 0.6, 94];

Warcry = [FFG[0], 36*FFG[1], FFG[2]];
Test = [10, 10, 15];

set(Test, seam=0, rise=1);
*deckbox(Boulder, ghost=true);
*deckbox(Boulder, lid=true);
