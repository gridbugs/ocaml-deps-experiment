#!/usr/bin/env bash
set -ex
./clean.sh

mkdir -p a_pub b_pub

FLAGS=

ocamlopt.opt $FLAGS -I a -c a/foo.ml -for-pack Internal_modules_of_a
ocamlopt.opt $FLAGS -I a -c a/bar.ml -for-pack Internal_modules_of_a
ocamlopt.opt $FLAGS -I a -c a/lib.ml -for-pack Internal_modules_of_a

ocamlopt.opt $FLAGS -pack -o a_pub/internal_modules_of_a.cmx a/foo.cmx a/bar.cmx a/lib.cmx

cat > a_pub/public_interface_to_open_of_a.ml <<EOF
module A = Internal_modules_of_a.Lib
module Internal_modules_of_a = struct end
EOF
ocamlopt.opt $FLAGS -I a_pub -c a_pub/public_interface_to_open_of_a.ml
ocamlopt.opt $FLAGS -a a_pub/internal_modules_of_a.cmx a_pub/public_interface_to_open_of_a.cmx -o a_pub/lib.cmxa

# End of build af package a

ocamlopt.opt $FLAGS -I a_pub -I b -c b/b_good.ml -open Public_interface_to_open_of_a -for-pack Internal_modules_of_b
ocamlopt.opt $FLAGS -I a_pub -I b -c b/lib.ml -open Public_interface_to_open_of_a -for-pack Internal_modules_of_b

ocamlopt.opt $FLAGS -pack -o b_pub/internal_modules_of_b.cmx b/b_good.cmx b/lib.cmx

cat > b_pub/public_interface_to_open_of_b.ml <<EOF
module B = Internal_modules_of_b.Lib
module Internal_modules_of_b = struct end
EOF
ocamlopt.opt $FLAGS -I b_pub -c b_pub/public_interface_to_open_of_b.ml
ocamlopt.opt $FLAGS -a b_pub/internal_modules_of_b.cmx b_pub/public_interface_to_open_of_b.cmx -o b_pub/lib.cmxa

# End of build af package b
