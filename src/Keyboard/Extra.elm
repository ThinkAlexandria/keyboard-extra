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

{-| Add simple and complex hotkeys to your application with a single case
statement.

Some kinds of keycombinations you can dispatch against:

- Press and release A and B while Shift is held
- Press and release J while Shift and Tab are held down
- Press and release keys in a specific order A B C but not A C B

### Warning: This library does not implement debouncing logic.
When holding multiple keys down, you will usually see a stream of keyup and
keydown events for the last key to be held down. You will have to come up with
your own logic to handle the flickering of the last key if your application
relies on multiple key press and hold combos.

# Wiring
@docs Msg, Model, subscriptions, init, update

# Helpers
Prefer to use helper functions on the Keyboard.Extra.Model to get the Nth most
recent key press rather than directly accessing the Model fields. The helper
function API will almost certainly not change, but the Model type almost
certainly will.
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


{-| A record containing a keyState field designed to be used directly in case
statements. The first element of the keyState tuple is the list of keys pressed
sorted by KeyCode. The assumptions being when a key combo
requires multiple keys being held down, the exact order of keydown events does
not matter.

Example:

    -- This is a valid model
    { keyState = ( [ Tab, Shift, CharD ], [] )
    , pressHistory = [ Tab, CharD, Shift ]
    -- ...
    }

    -- Another valid history
    { keyState = ( [ Tab, Shift, CharD ], [] )
    , pressHistory = [ CharD, Shift, Tab ]
    -- ...
    }

The second element of the keyState tuple is a list of keys sorted by KeyCode.
 Both of the tuple elements are limited to a
length of 3 to help deal with missing onkeyup events that are swallowed by
browser bugs.

Example:

    -- This is a valid model
    { keyState = ( [ Shift, CharD ], [ Tab ] )
    , pressHistory = [ CharD, Shift ]
    , releaseHistory = [ Tab ]
    }

    -- After another release, note that keyState lists are sorted by KeyCode
    { keyState = ( [ CharD ], [ Tab, Shift ] )
    , pressHistory = [ CharD ]
    , releaseHistory = [ Shift, Tab ]
    }
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

When a duplicate keydown event arrives for any key already in the key down list
, that key is moved to the head of the pressHistory list, but the keyState field
will be unchanged because the set of keys pressed down has not changed.
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

