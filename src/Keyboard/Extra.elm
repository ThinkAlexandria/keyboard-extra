module Keyboard.Extra
  exposing
    ( init
    , update
    , subscriptions
    , Msg(..)
    , Model
    , mostRecentKeyDown
    , secondRecentKeyDown
    , thirdRecentKeyDown
    , mostRecentKeyUp
    )

{-| Convenience helpers for working with keyboard inputs.

# Wiring
@docs Msg, Model, subscriptions, init, update

# Helpers
@docs mostRecentKeyDown, secondRecentKeyDown, thirdRecentKeyDown, mostRecentKeyUp

-}

import Keyboard exposing (KeyCode)
import Dict exposing (Dict)
import Set exposing (Set)
import Tuple
import Json.Encode as Encode
import Json.Decode as Decode

import Keyboard.Extra.Keys exposing (Key(..), toKeyCode, fromKeyCode)

{-| The message type `Keyboard.Extra` uses.
-}
type Msg
  = Down KeyCode
  | Up KeyCode


{-| A record containing a keyState field intended to be used directly in case
statements. The keyState is tuple where the first element is a List of Keys
sorted by KeyCode. The list of keys pressed down is sorted by KeyCode to
simplify pattern matching statements. The second element is a List of Keys in
the order they were released. Both of the tuple elements are limited to a
length of 3 to help deal with missing onkeyup events that are swallowed by
browser bugs.

Prefer to use helper functions on the Keyboard.Extra.Model to get the Nth most
recent key press rather than directly accessing the Model fields. The helper
function API will almost certainly not change, but the Model type almost
certainly will.

-}
type alias Model =
  { keyState : (List Key, List Key)
  -- these are the ages of the 
  , pressHistory : List Key
  , releaseHistory : List Key
  }

{-| Use this to initialize the component.
-}
init : Model
init =
  { keyState = ( [], [] )
  , pressHistory = []
  , releaseHistory = []
  }


{-| You need to call this to have the component update.
-}
update : Msg -> Model -> Model
update msg model =
  case msg of
    Down code ->
      let
        key = fromKeyCode code
        {- Add the new keydown to the history. We replace an any existing key
        down events because we only care about which keys are held down. The
        order of held down buttons generally does not matter when writing
        hotkey combos because people have difficulty holding an arbitrary group
        of keys down in a certain order.
        -}
        newPressHistory = 
          model.pressHistory
            |> List.filter (\k -> k /= key) 
            |> (::) key
            |> List.take 3

        newKeysPressed = List.sortBy toKeyCode newPressHistory
      in
        { model
          | pressHistory = newPressHistory        
          , keyState = (newKeysPressed, Tuple.second model.keyState)
        }

    Up code ->
      let
        key = fromKeyCode code
        -- Remove the released key from the pressHistory
        newPressHistory = List.filter (\k -> k /= key) model.pressHistory
        -- Recompute the pressed key combo used for pattern matching 
        newKeysPressed = List.sortBy toKeyCode newPressHistory
        {- Add the released key to the history. We do not remove duplicate key
        ups because we may care about the order of completed key clicks
        -}
        newReleaseHistory =
          model.releaseHistory
            |> (::) key
            |> List.take 3
        -- recompute the released key combo used for pattern matching
        newKeysReleased = List.sortBy toKeyCode newReleaseHistory
      in
        { model
          | pressHistory = newPressHistory        
          , releaseHistory = newReleaseHistory
          , keyState = (newKeysPressed, newKeysReleased)
        }


{-| You will need to add this to your program's subscriptions.
-}
subscriptions : Sub Msg
subscriptions =
  Sub.batch
    [ Keyboard.downs Down
    , Keyboard.ups Up
    ]

{-| Figure out the most recently pressed key
-}
mostRecentKeyDown : Model -> Maybe Key
mostRecentKeyDown model =
  model.pressHistory
    |> List.head

{-| Figure out the second most recently pressed key
-}
secondRecentKeyDown : Model -> Maybe Key
secondRecentKeyDown model =
  model.pressHistory
    |> List.drop 1
    |> List.head

{-| Figure out the third most recently pressed key
-}
thirdRecentKeyDown : Model -> Maybe Key
thirdRecentKeyDown model =
  -- The press history is always sorted, no need for `List.sortBy Tuple.first`
  model.pressHistory
    |> List.drop 2
    |> List.head

{-| Figure out the most recently released key. Prefer using this function to
just pattern matching on the head of the list in second element of the
`keyState` tuple. Even though there is always only either one or zero elements,
I am looking still thinking of a way to represent
-}
mostRecentKeyUp : Model -> Maybe Key
mostRecentKeyUp model =
  model.releaseHistory
    |> List.head

