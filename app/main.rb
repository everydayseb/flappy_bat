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

# HIGH SCORE FILE
HIGH_SCORE_FILENAME = 'hiscore.txt'


def tick args

  defaults args
  render args
  inputs args
  calc args

  #args.gtk.slowmo! 4
  #args.outputs[:pixel_canvas].debug << args.state.player.merge(args.state.player.collider).merge({path: :solid, a: 128})
end

GTK.reset

def defaults args
  args.state.player ||= { x: 50, y: 240, w: 40, h: 40,
                          anchor_x: 0.5, anchor_y: 0.5,
                          path: 'sprites/bat.png',
                          source_x: 0, source_y: 0,
                          source_w: 40, source_h: 40,
                          dy: 0,
                          flapped_at: 0,
                          flap_distance: 50,
                          flap_duration: 11.5,
                          falling: true,
                        }
  args.state.player.collider = {x: args.state.player.x+2, y: args.state.player.y+5, w: 22, h: 18}
  args.state.floor ||=  { x: 0, y: 0, w: 180, h: 20,
                          path: 'sprites/floor.png'
                        }
  args.state.bg ||= {x: 100, y: 0, w: 360, h: 320, path: 'sprites/bg-scroll.png'}
  args.state.gravity ||= 0.01
  args.state.pipes ||= []
  args.state.game_started ||= false
  args.state.game_over ||= false
  args.state.game_over_at ||= 0
  args.state.score ||= 0
  args.state.scored_at ||= 0
  args.state.hiscore ||= args.gtk.read_file(HIGH_SCORE_FILENAME).to_i
  args.state.saved_hiscore = false
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

  # render ui
  args.outputs[:pixel_canvas].labels << { x: 90, y: 300, text: "#{args.state.score}",
                                          anchor_x: 0.5,
                                          r: 255, g: 255, b: 255,
                                          font: "fonts/quaver.ttf",
                                          size_px: 16} if args.state.game_started

  args.outputs[:pixel_canvas].sprites << args.state.bg

  args.outputs[:pixel_canvas].sprites << args.state.pipes
  args.outputs[:pixel_canvas].sprites << flapping_sprite(args)
  args.outputs[:pixel_canvas].sprites << args.state.floor
  
  render_title_instructions args
  render_game_over args

  #args.outputs[:pixel_canvas].debug.borders << args.state.player
end

def calc args

  unless args.state.game_started
    # render title 
    if flap_input? args
      args.state.game_started = true
    end
  end

  return unless args.state.game_started

  if args.state.game_over
    # let the player fall to the ground but stop everything else
    if args.state.player.y > args.state.floor.h + args.state.player.collider.h / 2
      apply_gravity args
    end

    if args.state.score > args.state.hiscore && !args.state.saved_hiscore
      args.state.hiscore = args.state.score
      args.gtk.write_file(HIGH_SCORE_FILENAME, args.state.score.to_s)
      args.state.args.state.saved_hiscore = true
    end

    if args.state.game_over_at.elapsed_time > 30
      if flap_input? args      
        args.state.score = 0
        args.state.pipes.clear
        args.state.player.y = 240
        args.state.bg.x = 100
        args.state.game_over = false
        args.state.saved_hiscore = false
      end
    end

    return
  end

  spawn_pipes args
  move_pipes args
  move_bg args

  # handle movement
  if args.state.player.flapped_at.elapsed_time > args.state.player.flap_duration
    args.state.player.falling = true
  end
  if !args.state.player.falling && args.state.player.flapped_at.elapsed_time < args.state.player.flap_duration
    #args.state.player.y += args.state.player.dy
    args.state.player.y = args.state.player.y.lerp(args.state.player.y + args.state.player.dy, 0.1)
  end
  if args.state.player.falling && args.state.player.flapped_at.elapsed_time > args.state.player.flap_duration + 3
    apply_gravity args
    args.state.player.flapped_at = 0
  end


  # handle collisions
  #args.state.player.collider.y -= 4
  if args.state.player.intersect_rect? args.state.floor
    args.outputs.sounds << "sounds/collide.wav"
    args.state.game_over = true
    args.state.game_over_at = Kernel.tick_count
  end

  args.state.pipes.each do |pipe| 
    if pipe.intersect_rect? args.state.player.merge(args.state.player.collider)
      args.outputs.sounds << "sounds/collide.wav" unless args.state.game_over
      args.state.game_over = true
      args.state.game_over_at = Kernel.tick_count
    end
  end

  # handle out of bounds
  if args.state.player.y - args.state.player.h / 2 > PIXEL_HEIGHT
    args.state.pipes.each do |pipe|
      if args.state.player.x > pipe.x
        args.outputs.sounds << "sounds/collide.wav" unless args.state.game_over
        args.state.game_over = true
        args.state.game_over_at = Kernel.tick_count
      end 
    end
  end

  # handle scoring
  args.state.pipes.each do |pipe|
    if args.state.player.x > pipe.x + pipe.w / 2 && args.state.scored_at.elapsed_time > 40
      args.state.scored_at = Kernel.tick_count
      args.state.score += 1
      args.outputs.sounds << "sounds/scored.wav"
    end
  end
end

def inputs args
  if flap_input? args
    args.state.player.flapped_at = Kernel.tick_count
    args.outputs.sounds << 'sounds/flap.wav' unless args.state.game_over
    args.state.player.dy = args.state.player.flap_distance
    args.state.player.falling = false
    # reset gravity? probably need an acceleration variable
    args.state.gravity = 0.01 unless args.state.game_over
  end
end

def spawn_pipes args
  if args.state.pipes_spawned_at.elapsed_time >= 60
    bottom_y = Numeric.rand(10..180) * -1
    top_y = PIXEL_HEIGHT + bottom_y - 2
    top_pipe = pipe(310, top_y, 40, 219, true)
    bottom_pipe = pipe(310, bottom_y, 40, 219, false)

    args.state.pipes << top_pipe
    args.state.pipes << bottom_pipe
    args.state.pipes_spawned_at = Kernel.tick_count
  end
end

def move_pipes args
  args.state.pipes.each do |pipe| 
    pipe.x = pipe.x.lerp(pipe.x - 6, 0.5)
    #pipe.x -= 1
  end
  
  args.state.pipes.reject! {|pipe| pipe.x < 0 - pipe.w}
end

def move_bg args
  args.state.bg.x = args.state.bg.x.lerp(args.state.bg.x - 1, 0.2)
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
    args.state.gravity += args.state.gravity unless args.state.gravity > 5.2
end

def flapping_sprite args
  if args.state.player.flapped_at == 0 || args.state.game_over || !args.state.game_started
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
    anchor_x: 0.5, anchor_y: 0.5,
    tile_x: 0 + (tile_index * args.state.player.w),
    tile_y: 0,
    tile_w: args.state.player.w,
    tile_h: args.state.player.h,
  }
end

def flap_input? args
  args.inputs.keyboard.key_up.space || args.inputs.mouse.click || !args.inputs.finger_one.nil?
end

def render_title_instructions args
  return if args.state.game_started

  args.outputs[:pixel_canvas].sprites << { x: 90, y: 120, w: 123, h: 88,
                                            anchor_x: 0.5,
                                            path: 'sprites/title.png'}

  args.outputs[:pixel_canvas].labels << { x: 90, y: 100,
                          alignment_enum: 1,
                          r: 255, g: 255, b: 255, a: 255,
                          text: "Press SPACE or CLICK MOUSE to start", 
                          font: 'fonts/quaver.ttf',
                          size_px: 8,}
end

def render_game_over args
  return unless args.state.game_over

  args.outputs[:pixel_canvas].sprites << { x: 20, y: 125, w: 140, h: 40,
                          r: 0, g: 0, b: 0, a: 220,
                          path: :solid }
  args.outputs[:pixel_canvas].labels << { x: 90, y: 195,
                                          text: "GAME OVER",
                                          alignment_enum: 1,
                                          r: 255, g: 255, b: 255,
                                          font: 'fonts/quaver.ttf',
                                          size_px: 24}
  args.outputs[:pixel_canvas].labels << { x: 30, y: 155,
                                          text: "Score: #{args.state.score}",
                                          r: 255, g: 255, b: 255,
                                          font: 'fonts/quaver.ttf',
                                          size_px: 8}
  args.outputs[:pixel_canvas].labels << { x: 30, y: 142,
                                          text: "Best: #{args.state.hiscore}",
                                          r: 255, g: 255, b: 255,
                                          font: 'fonts/quaver.ttf',
                                          size_px: 8}
end