------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                       S Y S T E M . I M A G E _ U                        --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 1992-2022, Free Software Foundation, Inc.         --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Numerics.Big_Numbers.Big_Integers_Ghost;
use Ada.Numerics.Big_Numbers.Big_Integers_Ghost;

package body System.Image_U is

   --  Ghost code, loop invariants and assertions in this unit are meant for
   --  analysis only, not for run-time checking, as it would be too costly
   --  otherwise. This is enforced by setting the assertion policy to Ignore.

   pragma Assertion_Policy (Ghost              => Ignore,
                            Loop_Invariant     => Ignore,
                            Assert             => Ignore,
                            Assert_And_Cut     => Ignore,
                            Subprogram_Variant => Ignore);

   package Unsigned_Conversion is new Unsigned_Conversions (Int => Uns);

   function Big (Arg : Uns) return Big_Integer renames
     Unsigned_Conversion.To_Big_Integer;

   function From_Big (Arg : Big_Integer) return Uns renames
     Unsigned_Conversion.From_Big_Integer;

   Big_10 : constant Big_Integer := Big (10) with Ghost;

   --  Maximum value of exponent for 10 that fits in Uns'Base
   function Max_Log10 return Natural is
     (case Uns'Base'Size is
        when 8   => 2,
        when 16  => 4,
        when 32  => 9,
        when 64  => 19,
        when 128 => 38,
        when others => raise Program_Error)
   with Ghost;

   ------------------
   -- Local Lemmas --
   ------------------

   procedure Lemma_Non_Zero (X : Uns)
   with
     Ghost,
     Pre  => X /= 0,
     Post => Big (X) /= 0;

   procedure Lemma_Div_Commutation (X, Y : Uns)
   with
     Ghost,
     Pre  => Y /= 0,
     Post => Big (X) / Big (Y) = Big (X / Y);

   procedure Lemma_Div_Twice (X : Big_Natural; Y, Z : Big_Positive)
   with
     Ghost,
     Post => X / Y / Z = X / (Y * Z);

   procedure Lemma_Unsigned_Width_Ghost
   with
     Ghost,
     Post => Unsigned_Width_Ghost = Max_Log10 + 2;

   ---------------------------
   -- Lemma_Div_Commutation --
   ---------------------------

   procedure Lemma_Non_Zero (X : Uns) is null;
   procedure Lemma_Div_Commutation (X, Y : Uns) is null;

   ---------------------
   -- Lemma_Div_Twice --
   ---------------------

   procedure Lemma_Div_Twice (X : Big_Natural; Y, Z : Big_Positive) is
      XY  : constant Big_Natural := X / Y;
      YZ  : constant Big_Natural := Y * Z;
      XYZ : constant Big_Natural := X / Y / Z;
      R   : constant Big_Natural := (XY rem Z) * Y + (X rem Y);
   begin
      pragma Assert (X = XY * Y + (X rem Y));
      pragma Assert (XY = XY / Z * Z + (XY rem Z));
      pragma Assert (X = XYZ * YZ + R);
      pragma Assert ((XY rem Z) * Y <= (Z - 1) * Y);
      pragma Assert (R <= YZ - 1);
      pragma Assert (X / YZ = (XYZ * YZ + R) / YZ);
      pragma Assert (X / YZ = XYZ + R / YZ);
   end Lemma_Div_Twice;

   --------------------------------
   -- Lemma_Unsigned_Width_Ghost --
   --------------------------------

   procedure Lemma_Unsigned_Width_Ghost is
   begin
      pragma Assert (Unsigned_Width_Ghost <= Max_Log10 + 2);
      pragma Assert (Big (Uns'Last) > Big_10 ** Max_Log10);
      pragma Assert (Big (Uns'Last) < Big_10 ** (Unsigned_Width_Ghost - 1));
      pragma Assert (Unsigned_Width_Ghost >= Max_Log10 + 2);
   end Lemma_Unsigned_Width_Ghost;

   --------------------
   -- Image_Unsigned --
   --------------------

   procedure Image_Unsigned
     (V : Uns;
      S : in out String;
      P : out Natural)
   is
      pragma Assert (S'First = 1);

      procedure Prove_Value_Unsigned
      with
        Ghost,
        Pre => S'First = 1
          and then S'Last < Integer'Last
          and then P in 2 .. S'Last
          and then S (1) = ' '
          and then Only_Decimal_Ghost (S, From => 2, To => P)
          and then Scan_Based_Number_Ghost (S, From => 2, To => P)
            = Wrap_Option (V),
        Post => Is_Unsigned_Ghost (S (1 .. P))
          and then Value_Unsigned (S (1 .. P)) = V;
      --  Ghost lemma to prove the value of Value_Unsigned from the value of
      --  Scan_Based_Number_Ghost on a decimal string.

      --------------------------
      -- Prove_Value_Unsigned --
      --------------------------

      procedure Prove_Value_Unsigned is
         Str : constant String := S (1 .. P);
      begin
         pragma Assert (Str'First = 1);
         pragma Assert (Only_Decimal_Ghost (Str, From => 2, To => P));
         Prove_Iter_Scan_Based_Number_Ghost (S, Str, From => 2, To => P);
         pragma Assert (Scan_Based_Number_Ghost (Str, From => 2, To => P)
            = Wrap_Option (V));
         Prove_Scan_Only_Decimal_Ghost (Str, V);
      end Prove_Value_Unsigned;

   --  Start of processing for Image_Unsigned

   begin
      S (1) := ' ';
      P := 1;
      Set_Image_Unsigned (V, S, P);

      Prove_Value_Unsigned;
   end Image_Unsigned;

   ------------------------
   -- Set_Image_Unsigned --
   ------------------------

   procedure Set_Image_Unsigned
     (V : Uns;
      S : in out String;
      P : in out Natural)
   is
      Nb_Digits : Natural := 0;
      Value     : Uns := V;

      --  Local ghost variables

      Pow        : Big_Positive := 1 with Ghost;
      S_Init     : constant String := S with Ghost;
      Prev, Cur  : Uns_Option with Ghost;
      Prev_Value : Uns with Ghost;
      Prev_S     : String := S with Ghost;

      --  Local ghost lemmas

      procedure Prove_Character_Val (R : Uns)
      with
        Ghost,
        Pre  => R in 0 .. 9,
        Post => Character'Val (48 + R) in '0' .. '9';
      --  Ghost lemma to prove the value of a character corresponding to the
      --  next figure.

      procedure Prove_Hexa_To_Unsigned_Ghost (R : Uns)
      with
        Ghost,
        Pre  => R in 0 .. 9,
        Post => Hexa_To_Unsigned_Ghost (Character'Val (48 + R)) = R;
      --  Ghost lemma to prove that Hexa_To_Unsigned_Ghost returns the source
      --  figure when applied to the corresponding character.

      procedure Prove_Unchanged
      with
        Ghost,
        Pre  => P <= S'Last
          and then S_Init'First = S'First
          and then S_Init'Last = S'Last
          and then (for all K in S'First .. P => S (K) = S_Init (K)),
        Post => S (S'First .. P) = S_Init (S'First .. P);
      --  Ghost lemma to prove that the part of string S before P has not been
      --  modified.

      procedure Prove_Iter_Scan
        (Str1, Str2 : String;
         From, To : Integer;
         Base     : Uns := 10;
         Acc      : Uns := 0)
      with
        Ghost,
        Pre  => Str1'Last /= Positive'Last
          and then
            (From > To or else (From >= Str1'First and then To <= Str1'Last))
          and then Only_Decimal_Ghost (Str1, From, To)
          and then Str1'First = Str2'First
          and then Str1'Last = Str2'Last
          and then (for all J in From .. To => Str1 (J) = Str2 (J)),
        Post =>
          Scan_Based_Number_Ghost (Str1, From, To, Base, Acc)
            = Scan_Based_Number_Ghost (Str2, From, To, Base, Acc);
      --  Ghost lemma to prove that the result of Scan_Based_Number_Ghost only
      --  depends on the value of the argument string in the (From .. To) range
      --  of indexes. This is a wrapper on Prove_Iter_Scan_Based_Number_Ghost
      --  so that we can call it here on ghost arguments.

      -----------------------------
      -- Local lemma null bodies --
      -----------------------------

      procedure Prove_Character_Val (R : Uns) is null;
      procedure Prove_Hexa_To_Unsigned_Ghost (R : Uns) is null;
      procedure Prove_Unchanged is null;

      ---------------------
      -- Prove_Iter_Scan --
      ---------------------

      procedure Prove_Iter_Scan
        (Str1, Str2 : String;
         From, To : Integer;
         Base     : Uns := 10;
         Acc      : Uns := 0)
      is
      begin
         Prove_Iter_Scan_Based_Number_Ghost (Str1, Str2, From, To, Base, Acc);
      end Prove_Iter_Scan;

   --  Start of processing for Set_Image_Unsigned

   begin
      pragma Assert (P >= S'First - 1 and then P < S'Last and then
                     P < Natural'Last);
      --  No check is done since, as documented in the specification, the
      --  caller guarantees that S is long enough to hold the result.

      Lemma_Unsigned_Width_Ghost;

      --  First we compute the number of characters needed for representing
      --  the number.
      loop
         Lemma_Div_Commutation (Value, 10);
         Lemma_Div_Twice (Big (V), Big_10 ** Nb_Digits, Big_10);

         Value := Value / 10;
         Nb_Digits := Nb_Digits + 1;
         Pow := Pow * 10;

         pragma Loop_Invariant (Nb_Digits in 1 .. Unsigned_Width_Ghost - 1);
         pragma Loop_Invariant (Pow = Big_10 ** Nb_Digits);
         pragma Loop_Invariant (Big (Value) = Big (V) / Pow);
         pragma Loop_Variant (Decreases => Value);

         exit when Value = 0;

         Lemma_Non_Zero (Value);
         pragma Assert (Pow <= Big (Uns'Last));
      end loop;

      Value := V;
      Pow := 1;

      pragma Assert (Value = From_Big (Big (V) / Big_10 ** 0));

      --  We now populate digits from the end of the string to the beginning
      for J in reverse 1 .. Nb_Digits loop
         Lemma_Div_Commutation (Value, 10);
         Lemma_Div_Twice (Big (V), Big_10 ** (Nb_Digits - J), Big_10);
         Prove_Character_Val (Value rem 10);
         Prove_Hexa_To_Unsigned_Ghost (Value rem 10);

         Prev_Value := Value;
         Prev_S := S;
         Pow := Pow * 10;

         S (P + J) := Character'Val (48 + (Value rem 10));
         Value := Value / 10;

         pragma Assert (S (P + J) in '0' .. '9');
         pragma Assert (Hexa_To_Unsigned_Ghost (S (P + J)) =
           From_Big (Big (V) / Big_10 ** (Nb_Digits - J)) rem 10);
         pragma Assert
           (for all K in P + J + 1 .. P + Nb_Digits => S (K) in '0' .. '9');
         pragma Assert
           (for all K in P + J + 1 .. P + Nb_Digits =>
              Hexa_To_Unsigned_Ghost (S (K)) =
                From_Big (Big (V) / Big_10 ** (Nb_Digits - (K - P))) rem 10);

         Prev := Scan_Based_Number_Ghost
           (Str  => S,
            From => P + J + 1,
            To   => P + Nb_Digits,
            Base => 10,
            Acc  => Prev_Value);
         Cur := Scan_Based_Number_Ghost
           (Str  => S,
            From => P + J,
            To   => P + Nb_Digits,
            Base => 10,
            Acc  => Value);

         if J /= Nb_Digits then
            pragma Assert
              (Prev_Value = 10 * Value + Hexa_To_Unsigned_Ghost (S (P + J)));
            Prove_Iter_Scan
              (Prev_S, S, P + J + 1, P + Nb_Digits, 10, Prev_Value);
         end if;

         pragma Assert (Prev = Cur);
         pragma Assert (Prev = Wrap_Option (V));

         pragma Loop_Invariant (Value <= Uns'Last / 10);
         pragma Loop_Invariant
           (for all K in S'First .. P => S (K) = S_Init (K));
         pragma Loop_Invariant (Only_Decimal_Ghost (S, P + J, P + Nb_Digits));
         pragma Loop_Invariant
           (for all K in P + J .. P + Nb_Digits => S (K) in '0' .. '9');
         pragma Loop_Invariant
           (for all K in P + J .. P + Nb_Digits =>
              Hexa_To_Unsigned_Ghost (S (K)) =
                From_Big (Big (V) / Big_10 ** (Nb_Digits - (K - P))) rem 10);
         pragma Loop_Invariant (Pow = Big_10 ** (Nb_Digits - J + 1));
         pragma Loop_Invariant (Big (Value) = Big (V) / Pow);
         pragma Loop_Invariant
           (Scan_Based_Number_Ghost
              (Str  => S,
               From => P + J,
               To   => P + Nb_Digits,
               Base => 10,
               Acc  => Value)
              = Wrap_Option (V));
      end loop;

      Prove_Unchanged;
      pragma Assert
        (Scan_Based_Number_Ghost
           (Str  => S,
            From => P + 1,
            To   => P + Nb_Digits,
            Base => 10,
            Acc  => Value)
         = Wrap_Option (V));

      P := P + Nb_Digits;
   end Set_Image_Unsigned;

end System.Image_U;
