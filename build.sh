#!/usr/bin/env bash
set -ex
./clean.sh

mkdir -p a_pub b_pub c_pub d_pub e_pub

FLAGS=

# Build package a
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

# Build package b

ocamlopt.opt $FLAGS -I a_pub -I b -c b/b_good.ml -open Public_interface_to_open_of_a -for-pack Internal_modules_of_b
ocamlopt.opt $FLAGS -I a_pub -I b -c b/lib.ml -open Public_interface_to_open_of_a -for-pack Internal_modules_of_b

ocamlopt.opt $FLAGS -pack -o b_pub/internal_modules_of_b.cmx b/b_good.cmx b/lib.cmx

cat > b_pub/public_interface_to_open_of_b.ml <<EOF
(* This file's module is expected to be passed with -open when compiling each
   module of each package depending on this package. The public interface to
   this package is defined in a module named Lib, which is aliased to this
   package's name here, which will make the public interface to this module
   available to client code under a module named after this package. *)
module B = Internal_modules_of_b.Lib

(* Shadow the internal modules of this package. When compiling modules from
   packages that depend on this package, the public directory of this package
   must be passed with -I to allow its internal modules to be aliased in its
   public interface. However doing so would leak all private modules to client
   code. To prevent this, the module containing all private modules of this
   package is shadowed here. *)
module Internal_modules_of_b = struct end

(* Shadow the internal modules of the transitive closure of this package. When
   compiling modules from packages that depend on this package, the public
   directories of all this package's transitive dependencies must be passed
   with -I to allow this package to define aliases to modules defined among its
   dependencies. However these directories contain files exposing internal
   modules from their respective packages which are shadowed in their
   corresponding public interfaces, and packages depending on this package
   don't necessarily depend on each package in its transitive closure, so won't
   open the modules necessary to shadow the internal modules of each package in
   its transitive closure. Thus they must be shadowed again here. *)
module Internal_modules_of_a = struct end

(* Shadow the public interfaces to the transitive closure of this package. As
   described above, all the public directories of this package's transitive
   dependency closure are passed with -I while compiling client code. This
   would allow client code to access the public interface of any package from
   this package's dependency closure. To prevent this, the public interfaces to
   each package in this package's dependency closure is shadowed here. *)
module Public_interface_to_open_of_a = struct end
EOF
ocamlopt.opt $FLAGS -I b_pub -c b_pub/public_interface_to_open_of_b.ml
ocamlopt.opt $FLAGS -a b_pub/internal_modules_of_b.cmx b_pub/public_interface_to_open_of_b.cmx -o b_pub/lib.cmxa

# End of build af package b

# Build package c

# c depends on a and b. The transitive closure of its dependencies must be
# passed with -I, and immediate dependencies must be opened. When opening
# immediate dependencies, they must be opened in an order such that if one
# package depends on another (possibly transitively), it follows it (not
# necessarily directly) in the list of opens. This prevents the shadowing of
# public interface of transitive deps in the public interface to a package from
# shadowing immediate dependencies of the current package.
#
# Also this is a main file so don't compile it for a pack (omit the -pack argument).
ocamlopt.opt $FLAGS -I a_pub -I b_pub -I c -c c/main.ml -open Public_interface_to_open_of_a -open Public_interface_to_open_of_b

# When linking an executable, the cmxa files of its transitive dependency
# closure must be passed.
ocamlopt.opt $FLAGS a_pub/lib.cmxa b_pub/lib.cmxa c/main.cmx -o c_pub/c_main

# End of build af package c

# Build package d

# d depends on b only, but we still need "-I a_pub" to deal with module aliases
# that eventually resolve within a
ocamlopt.opt $FLAGS -I a_pub -I b_pub -I d -c d/lib.ml -open Public_interface_to_open_of_b -for-pack Internal_modules_of_d
ocamlopt.opt $FLAGS -pack -o d_pub/internal_modules_of_d.cmx d/lib.cmx


cat > d_pub/public_interface_to_open_of_d.ml <<EOF
module D = Internal_modules_of_d.Lib

module Internal_modules_of_d = struct end

module Internal_modules_of_a = struct end
module Internal_modules_of_b = struct end

module Public_interface_to_open_of_a = struct end
module Public_interface_to_open_of_b = struct end
EOF
ocamlopt.opt $FLAGS -I d_pub -c d_pub/public_interface_to_open_of_d.ml
ocamlopt.opt $FLAGS -a d_pub/internal_modules_of_d.cmx d_pub/public_interface_to_open_of_d.cmx -o d_pub/lib.cmxa

# End of build for package d

# Build package e

# e depends on d and a but not b, but still needs the union transitive closure
# of both to be passed with -I. When opening files, a must come before d
# because d depends (transitively) on a.
ocamlopt.opt $FLAGS -I a_pub -I b_pub -I d_pub -I e -c e/main.ml -open Public_interface_to_open_of_a -open Public_interface_to_open_of_d

# Link e's executable. Pass the cmxa files for e's transitive closure.
ocamlopt.opt $FLAGS a_pub/lib.cmxa b_pub/lib.cmxa d_pub/lib.cmxa e/main.cmx -o e_pub/e_main
