local map = ...

function temp:on_activated()

  -- We don't use a jumper here because we don't want the delay.
  sol.audio.play_sound("secret")
end

function temp2:on_activated()

  -- We don't use a jumper here because we don't want the delay.
  sol.audio.play_sound("jump")
end
