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

gap_min = 0.1;
gap_vertical = max(gap_min, layer_height);
wall_min = 2 * xwall(3) + gap_min;

module deckbox(in, wall=wall_min, join=10, seam=0.33, rise=0.34, lid=false,
               ghost=undef) {
    if (ghost) %deckbox(in, wall, join, seam, rise, lid=!lid, ghost=false);
    else if (is_undef(ghost)) %cube(in, center=true);
    // TODO: define internal dividers
    jwall = fthin(wall/2);
    out = in + 2 * [wall, wall, wall];
    w = out[0];
    d = out[1];
    h = out[2];
    z1 = rise * (h - join);
    z0 = (lid ? 1 - rise - seam : seam) * (h - join);
    slope = [[-d/2-wall, z0-h/2], [-d/2+wall, z0-h/2],
             [d/2-wall, z0+z1-h/2], [d/2+wall, z0+z1-h/2],
             [d/2+wall, h/2+wall], [-d/2-wall, h/2+wall]];
    gap_lid = lid ? 0 : gap_vertical;
    rotate([lid ? 180 : 0, 0, 0]) {
        difference() {
            union() {
                difference() {
                    cube(in + 2 * [wall, wall, wall], center=true);
                    rotate([90, 0, 90]) linear_extrude(w+2*wall, center=true)
                        polygon(slope);
                }
                if (lid) {
                    difference() {
                        cube(out, center=true);
                        cube(out-[2*jwall, 2*jwall, -tolerance], center=true);
                    }
                }
                else cube(in+[2*jwall, 2*jwall, -tolerance], center=true);
            }
            cube(in, center=true);
            translate([0, 0, join-gap_lid]) rotate([90, 0, 90])
                linear_extrude(w+2*wall, center=true) polygon(slope);
        }
    }
}

module deckbox_set(in, wall=wall_min, join=10, seam=0.33, rise=0.34) {
    translate([in[0]/2+2*wall, 0, 0])
        deckbox(in, wall, join, seam, rise);
    translate([-in[0]/2-2*wall, 0, 0])
        rotate([180, 0, 0]) deckbox(in, wall, join, seam, rise, lid=true);
}

Boulder = [68.5, 67.5, 93];
FFG = [66.5, 0.6, 94];

Warcry = [FFG[0], 36*FFG[1], FFG[2]];
Test = [15, 10, 20];

deckbox_set([10, 5, 15], join=5);
*deckbox(Boulder);
*deckbox(Boulder, lid=true);
