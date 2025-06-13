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
  calc args
end

GTK.reset

def defaults args
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
end

def calc args
  spawn_pipes args
  move_pipes args
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