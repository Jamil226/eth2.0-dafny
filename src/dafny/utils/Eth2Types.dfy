/*
 * Copyright 2020 ConsenSys AG.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may 
 * not use this file except in compliance with the License. You may obtain 
 * a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software dis-
 * tributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
 * License for the specific language governing permissions and limitations 
 * under the License.
 */

include "NativeTypes.dfy"
include "../utils/Helpers.dfy"
include "../utils/MathHelpers.dfy"

/** 
 * Define the types used in the Eth2.0 spec.
 * From types.k in the Eth2 spec.
 *
 */
module Eth2Types {

    import opened NativeTypes
    import opened Helpers
    import opened MathHelpers

    //  The Eth2 basic types.

    /** The type `byte` corresponds to a 'uint8' */
    type byte = uint8
    /** The type `bytes` corresponds to a sequence of 'Bytes's */
    type bytes = seq<byte>

    datatype BitlistWithLength = BitlistWithLength(s:seq<bool>,limit:nat)

    type CorrectBitlist = u:BitlistWithLength | |u.s| <= u.limit witness BitlistWithLength([],0)

    /** The default zeroed Bytes32.  */
    // const SEQ_EMPTY_32_BYTES := timeSeq<byte>(0,32)

    /** The type `Seq32Byte` corresponding to sequences of 32 `Bytes`s */
    type Seq32Byte = x:seq<byte> | |x| == 32 witness timeSeq(0 as byte, 32)
    // SEQ_EMPTY_32_BYTES

    /** Create type synonym for a chunk */
    type chunk = Seq32Byte

    /** Create type synonym for a hash 'root' */
    type hash32 = Seq32Byte

    /** The serialisable objects. */
    datatype RawSerialisable = 
            Uint8(n: uint8)
        |   Bool(b: bool)
        |   Bitlist(xl: seq<bool>, limit:nat)
        |   Bytes(bs: seq<byte>)
        |   List(l:seq<RawSerialisable>, t:Tipe, limit: nat)
        |   Vector(v:seq<RawSerialisable>)
        |   Container(fl: seq<RawSerialisable>)

    /** Well typed predicate for `RawSerialisable`s
     * @param s `RawSerialisable` value
     * @returns `true` iff `s` is a legal value for serialisation and
     *           merkleisation
     */    
    predicate wellTyped(s:RawSerialisable)
    decreases s, 0
    {
        match s 
            case Bool(_) => true
    
            case Uint8(_) => true

            case Bitlist(xl,limit) => |xl| <= limit

            case Bytes(bs) => |bs| > 0

            case Container(_) => forall i | 0 <= i < |s.fl| :: wellTyped(s.fl[i])

            case List(l, t, limit) =>   && |l| <= limit
                                        && limit > 0
                                        && (forall i | 0 <= i < |l| :: wellTyped(l[i]))                                   
                                        && forall i | 0 <= i < |l| :: typeOf(l[i]) == t

            case Vector(v) =>   && |v| > 0
                                && (forall i | 0 <= i < |v| :: wellTyped(v[i])) 
                                && forall i,j | 0 <= i < |v| && 0 <= j < |v| :: typeOf(v[i]) == typeOf(v[j])

    }

    /**
     * The type `Serialisable` corresponds to well typed `RawSerialisable`s
     */
    type Serialisable = s:RawSerialisable | wellTyped(s) witness Uint8(0)

    /**
     * Helper function to cast a well typed `RawSerialisable` to a
     * `Serialisable`. Its mainly usage is for the cases where `Serialisable` is
     * used as type parameter.
     * 
     * @param s RawSerialisable value
     * @returns `s` typed as `Serialisable`
     */
    function method castToSerialisable(s:RawSerialisable):Serialisable
    requires wellTyped(s)
    {
        s
    }

    // type CorrectlyTypedSerialisable = s:Serialisable | s.List? ==> 

    /** The type `Bytes4` corresponds to a Serialisable built using the
     * `Bytes` constructor passing a sequence of 4 `byte`s to it
     */
    type Bytes4 = s:Serialisable |  s.Bytes? && |s.bs| == 4
                                    witness Bytes(timeSeq(0 as byte, 4))

    /** The type `Bytes32` corresponds to a Serialisable built using the
     * `Bytes` constructor passing a sequence of 32 `byte`s to it
     */
    type Bytes32 = s:Serialisable | s.Bytes? && |s.bs| == 32
                                    witness Bytes(timeSeq(0 as byte, 32))

    /** The type `Bytes48` corresponds to a Serialisable built using the
     * `Bytes` constructor passing a sequence of 48 `byte`s to it
     */
    type Bytes48 = s:Serialisable | s.Bytes? && |s.bs| == 48
                                    witness Bytes(timeSeq(0 as byte, 48))

    /** The type `Bytes96` corresponds to a Serialisable built using the
     * `Bytes` constructor passing a sequence of 96 `byte`s to it
     */
    type Bytes96 = s:Serialisable | s.Bytes? && |s.bs| == 96
                                    witness Bytes(timeSeq(0 as byte, 96))

    // EMPTY_BYTES32

    // const EMPTY_BYTES32 := Bytes32(SEQ_EMPTY_32_BYTES)
    
    type Root = Bytes32

    /** Some type tags.
     * 
     *  In Dafny we cannot extract the type of a given object.
     *  In the proofs, we need to specify the type when deserialise is called
     *  and also to prove some lemmas.
     */
    datatype Tipe =
            Uint8_
        |   Bool_
        |   Bitlist_(limit:nat)
        |   Bytes_(len:nat)
        |   Container_
        |   List_(t:Tipe, limit:nat)
        |   Vector_(t:Tipe, len:nat)

    /**
     * Check if a `Tipe` is the representation of a basic `Serialisable` type
     *
     * @param t The `Tipe` value
     * @returns `true` iff `t` is the representation of a basic `Serialisable`
     *          type
     */
    predicate method isBasicTipe(t:Tipe)
    {
        t in {Bool_, Uint8_}
    }

   /**  The Tipe of a serialisable.
     *  This function allows to obtain the type of a `Serialisable`.
     *  
     *  @param  s   A serialisable.
     *  @returns    Its tipe.
     */
    function method typeOf(s : RawSerialisable) : Tipe 
    requires wellTyped(s)
    decreases s
    {
            match s 
                case Bool(_) => Bool_
        
                case Uint8(_) => Uint8_

                case Bitlist(_,limit) => Bitlist_(limit)

                case Bytes(bs) => Bytes_(|bs|)

                case Container(_) => Container_

                case List(l, t, limit) =>   List_(t, limit)

                case Vector(v) => Vector_(typeOf(v[0]),|v|)
    }

    /**
     * Bitwise exclusive-or of two `byte` value
     *
     * @param a  First value
     * @param b  Second value
     * @returns  Bitwise exclusive-or of `a` and `b`
     */
    function byteXor(a:byte, b:byte): byte
    {
        ((a as bv8)^(b as bv8)) as byte
    }      

    //  Old section

    /** Simple Serialisable types. */
    trait SSZ {
        /** An SSZ must offer an encoding into array of bytes. */
        function hash_tree_root () : HashTreeRoot 
    }

    /* A String type. */
    type String = seq<char>

    type HashTreeRoot = Option<array<byte>>
    // Basic Python (SSZ) types.
    /* Hash. (Should probably be a fix-sized bytes. */
    type Hash = Bytes32

    //  TODO: change the Bytes type
    // type SerialisedBytes = seq<byte> 
    
    type BLSPubkey = String
    type BLSSignature = String      //a BLS12-381 signature.

    type Slot = uint64
    type Gwei = int

    // Custom types

    /* Validator registry index. */
    type ValidatorIndex = Option<int>

    // List types
    // Readily available in Dafny as seq<T>

    // Containers

    /**
     *  A fork.
     *
     *  @param  version         The version. (it was forked at?)
     *  @param  currentVersion  The current version.
     *  @param  epoch           The epoch of the latest fork.
     */
    class Fork extends SSZ {
        var version: int
        var currentVersion : int
        var epoch: int

        /** Generate a hash tree root.  */
        function hash_tree_root() : HashTreeRoot {
            None
        }
    }

    /** 
     *  A Checkpoint. 
     *
     *  @param  epoch   The epoch.
     *  @param  hash    The hash.
     */
    class CheckPoint {
        var epoch: int
        var hash: Hash

        /** Generate a hash tree root.  */
        function hash_tree_root() : HashTreeRoot {
            None
        }
    }
}