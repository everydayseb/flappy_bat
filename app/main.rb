# Logical canvas width and height
WIDTH = 720
HEIGHT = 1280

# pixel art dimensions
PIXEL_WIDTH = 180
PIXEL_HEIGHT = 320

# Determine best fit zoom level
ZOOM_WIDTH = (WIDTH / PIXEL_WIDTH).floor
ZOOM_HEIGHT = (HEIGHT / PIXEL_HEIGHT).floor
ZOOM = [ZOOM_WIDTH, ZOOM_HEIGHT].min

# Compute the offset to center the screen
OFFSET_X = (WIDTH - PIXEL_WIDTH * ZOOM) / 2
OFFSET_Y = (HEIGHT - PIXEL_HEIGHT * ZOOM) / 2

# Compute the scaled dimensions of the screen
ZOOMED_WIDTH = PIXEL_WIDTH * ZOOM
ZOOMED_HEIGHT = PIXEL_HEIGHT * ZOOM


def tick args

  defaults args
  render args
  inputs args
  calc args
end

GTK.reset

def defaults args
  args.state.player ||= { x: 40, y: 160, w: 40, h: 40,
                          anchor_x: 0.5, anchor_y: 0.5,
                          path: 'sprites/bat.png',
                          source_x: 0, source_y: 0,
                          source_w: 40, source_h: 40,
                          dy: 0,
                          flapped_at: 0,
                          flap_distance: 50,
                          flap_duration: 8,
                          falling: true,
                          collider: {w: 38, h: 38} }
  args.state.gravity ||= 0.02
  args.state.pipes ||= []
end

def render args
  # bg color
  args.outputs.background_color = [20, 24, 46]

  # define a render target that represents the pixel art canvas dimensions
  args.outputs[:pixel_canvas].w = PIXEL_WIDTH
  args.outputs[:pixel_canvas].h = PIXEL_HEIGHT
  args.outputs[:pixel_canvas].background_color = [20, 24, 46]

  # draw to render target
  args.outputs[:pixel_canvas].sprites << {x: 0, y: 0, w: 180, h: 320, path: 'sprites/bg.png'}

  # scale render target and draw to screen
  args.outputs.sprites << { x: WIDTH / 2, y: HEIGHT / 2, 
                            w: ZOOMED_WIDTH, h: ZOOMED_HEIGHT,
                            anchor_x: 0.5, anchor_y: 0.5,
                            path: :pixel_canvas }

  args.outputs[:pixel_canvas].sprites << args.state.pipes
  args.outputs[:pixel_canvas].sprites << flapping_sprite(args)
end

def calc args
  spawn_pipes args
  move_pipes args

  # handle movement
  if args.state.player.flapped_at.elapsed_time > args.state.player.flap_duration
    args.state.player.falling = true
  end
  if !args.state.player.falling && args.state.player.flapped_at.elapsed_time < args.state.player.flap_duration
    #args.state.player.y += args.state.player.dy
    args.state.player.y = args.state.player.y.lerp(args.state.player.y + args.state.player.dy, 0.1)
  end
  if args.state.player.falling && args.state.player.flapped_at.elapsed_time > args.state.player.flap_duration + 1
    apply_gravity args
    args.state.player.flapped_at = 0
  end
end

def inputs args
  if args.inputs.keyboard.key_up.space
    args.state.player.flapped_at = Kernel.tick_count
    args.outputs.sounds << 'sounds/flap.wav'
    args.state.player.dy = args.state.player.flap_distance
    args.state.player.falling = false
    # reset gravity? probably need an acceleration variable
    args.state.gravity = 0.02
  end
end

def spawn_pipes args
  if args.state.pipes_spawned_at.elapsed_time >= 150
    gap_height = 30
    bottom_y = 0 - Numeric.rand(40..200) 
    #top_y = PIXEL_HEIGHT + bottom_y + gap_height
    top_y = PIXEL_HEIGHT + bottom_y + gap_height
    top_pipe = pipe(180, top_y, 44, 219, true)
    bottom_pipe = pipe(180, bottom_y, 44, 219, false)

    args.state.pipes << top_pipe
    args.state.pipes << bottom_pipe
    args.state.pipes_spawned_at = Kernel.tick_count
  end
end

def move_pipes args
  args.state.pipes.each do |pipe| 
    pipe.x = pipe.x.lerp(pipe.x - 2, 0.5)
    #pipe.x -= 1
  end
  
  args.state.pipes.reject! {|pipe| pipe.x < 0 - pipe.w}
end

def pipe x, y, w, h, flipped
  {
    x: x,
    y: y,
    w: w,
    h: h,
    path: "sprites/pipe.png",
    flip_vertically: flipped,
  }
end

def apply_gravity args
    args.state.player.y -= args.state.gravity
    args.state.gravity += args.state.gravity unless args.state.gravity > 5
end

def flapping_sprite args
  if args.state.player.flapped_at == 0
    tile_index = 0
  else
    how_many_frames_in_sprite_sheet = 3
    how_many_ticks_to_hold_each_frame = 6
    should_the_index_repeat = true
    tile_index = args.state
                      .player
                      .flapped_at
                      .frame_index(how_many_frames_in_sprite_sheet,
                                  how_many_ticks_to_hold_each_frame,
                                  should_the_index_repeat)
  end

  {
    x: args.state.player.x,
    y: args.state.player.y,
    w: args.state.player.w,
    h: args.state.player.h,
    path: 'sprites/bat.png',
    tile_x: 0 + (tile_index * args.state.player.w),
    tile_y: 0,
    tile_w: args.state.player.w,
    tile_h: args.state.player.h,
  }
end