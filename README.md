# Keyboard Extra

Forked from: https://github.com/ohanhi/keyboard-extra.

### Description

Intended to keep track of the current keys being pressed, but to avoid bugs
where `onKeyUp` does not always get triggered for all the keys pressed down,
this only keeps track of the last 3 keys. This way if a key gets added for
`onKeyDown` and doesn't get removed for `onKeyUp`, it can be cleared by pressing
a few different more keys.

[Stack Overflow Post Talking about missing `onKeyUp` event](http://stackoverflow.com/questions/27380018/when-cmd-key-is-kept-pressed-keyup-is-not-triggered-for-any-other-key)

This library is not designed for games, it's designed for apps where you want
to add hotkeys to trigger certain events. This version only supports key combos
with multiple keys held down and one key released. Key combos that
rely on holding multiple keys and then reacting only when all of those keys
have been released are not supported. My application does not yet need to have
multiple keys released, so I did not implement that functionality. PRs welcome.

### Usage

Add it to your Model:

```elm
type alias Model =
    { keysDown : Keyboard.Extra.Model
    -- ...
    }
```

Add it to your init:

```elm
init =
    { keysDown = Keyboard.Extra.init
    -- ...
    }

-- If your init also expects a Cmd then pair it with Cmd.none.
```

Add it to your messages:

```elm
type Msg =
    KeyboardExtraMsg Keyboard.Extra.Msg
    -- ...
```

Add it to your update.

The `List` of pressed `Keys` will be sorted by the `Keyboard.Extra.update` to
avoid having to pattern match all possible orders of key presses. This means
when you must manually sort the list of Keys in your pattern matching by KeyCode
value. This is a huge pain

```elm
update msg model =
  case msg of
    KeyboardExtraMsg keyMsg ->
      updateKeysDown keyMsg model

  -- ..

updateKeysDown : Keyboard.Extra.Msg -> Model -> Model
updateKeysDown keyMsg model =
  let
    newKeysDown = Keyboard.Extra.update keyMsg model.keysDown
    -- dont forget to update the Keyboard.Extra.Model
    newModel = { model | keysDown = newKeysDown }
  in
    case newKeysDown.keyState of
      -- Tab has KeyCode of 9 and Shift has KeyCode of 16.
      ( [ Tab, Shift ], Just keyPressed ) ->
        -- handle all hotkeys groups that require tab and shift to be held
        case keyPressed of
          CharC ->
            copySelection newModel

          CharV ->
            pasteSelection newModel

          CharX ->
            cutSelection newModel

      ( [ Meta, Control, Plus ], Nothing ) ->
        handleSomeBizareHotkeyGroup newModel

      _ ->
        newModel
```

And lastly, hook up your subscriptions:

```elm
subscriptions model =
    Sub.batch
       [ Sub.map KeyboardExtraMsg Keyboard.Extra.subscriptions
       -- ...
       ]
```

### Common Pitfalls

Let's say you add a hotkey for a double-key, like shift-tab, and you want the
user to not only be able to click shift-tab multiple times, but click shift-tab
and hold on to shift again but keep clicking tab. This is relatively standard
behaviour and someone is _likely_ to do this over letting go of the shift every
time. Let's take a look at what happens:

1. Event: keydown Shift -> Model: { keyState = ( [ Shift ], Nothing) ... }
2. Event: keydown Tab   -> Model: { keyState = ( [ Tab, Shift ], Nothing) ... }
3. Event: keyup   Tab   -> Model: { keyState = ( [ Shift ], Just Tab) ... }
4. Event: keydown Tab   -> Model: { keyState = ( [ Tab, Shift ], Nothing) ... }
5. Event: keyup   Tab   -> Model: { keyState = ( [ Tab, Shift ], Just Tab) ... }
6. Event: keydown Tab   -> Model: { keyState = ( [ Tab, Shift ], Nothing) ... }

