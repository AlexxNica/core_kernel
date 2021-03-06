open! Import

(* WARNING:
   We use non-memory-safe things throughout the [Trusted] module.
   Most of it is only safe in combination with the type signature (e.g. exposing
   [val copy : 'a t -> 'b t] would be a big mistake). *)
module Trusted : sig

  type 'a t
  val empty : 'a t
  val unsafe_create_uninitialized : len:int -> 'a t
  val get : 'a t -> int -> 'a
  val set : 'a t -> int -> 'a -> unit
  val unsafe_get : 'a t -> int -> 'a
  val unsafe_set : 'a t -> int -> 'a -> unit
  val length : 'a t -> int
  val unsafe_blit : ('a t, 'a t) Blit.blit
  val copy : 'a t -> 'a t

end = struct

  type 'a t = Obj_array.t

  let empty = Obj_array.empty

  let unsafe_create_uninitialized ~len = Obj_array.create ~len

  let get arr i = Obj.obj (Obj_array.get arr i)
  let set arr i x = Obj_array.set arr i (Obj.repr x)
  let unsafe_get arr i = Obj.obj (Obj_array.unsafe_get arr i)
  let unsafe_set arr i x = Obj_array.unsafe_set arr i (Obj.repr x)

  let length = Obj_array.length

  let unsafe_blit = Obj_array.unsafe_blit

  let copy = Obj_array.copy

end

include Trusted

let init l ~f =
  if l < 0 then invalid_arg "Uniform_array.init"
  else
    let res = unsafe_create_uninitialized ~len:l in
    for i = 0 to l - 1 do
      unsafe_set res i (f i)
    done;
    res

let of_array arr = init ~f:(Array.unsafe_get arr) (Array.length arr)

let map a ~f = init ~f:(fun i -> f (unsafe_get a i)) (length a)

let iter a ~f =
  for i = 0 to length a - 1 do
    f (unsafe_get a i)
  done

let to_list t = List.init ~f:(get t) (length t)

let of_list l =
  let len = List.length l in
  let res = unsafe_create_uninitialized ~len in
  List.iteri l ~f:(fun i x -> set res i x);
  res

let create ~len x =
  let res = unsafe_create_uninitialized ~len in
  for i = 0 to len-1
  do
    unsafe_set res i x
  done;
  res

(* It is not safe for [to_array] to be the identity function because we have code that
   relies on [float array]s being unboxed, for example in [bin_write_array]. *)
let to_array t = Array.init (length t) ~f:(fun i -> unsafe_get t i)

include Sexpable.Of_sexpable1(Array)(struct
    type nonrec 'a t = 'a t
    let to_sexpable = to_array
    let of_sexpable = of_array
  end)

include Binable.Of_binable1(Array)(struct
    type nonrec 'a t = 'a t
    let to_binable = to_array
    let of_binable = of_array
  end)

module Sequence = struct
  let length = length
  let get    = get
  let set    = set
end

include
  Test_blit.Make1_and_test
    (struct
      type nonrec 'a t = 'a t [@@deriving sexp_of]
      type 'a z = 'a
      include Sequence
      let create_like ~len t =
        if len = 0
        then empty
        else (assert (length t > 0); create ~len (get t 0))
      ;;
      let unsafe_blit = unsafe_blit
      let create_bool ~len = create ~len false
    end)
