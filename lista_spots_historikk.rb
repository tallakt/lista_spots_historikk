#!/usr/bin/env ruby
# encoding: utf-8

require 'yaml'
require 'sinatra'
require "sinatra/reloader" if development?


# TODO Filter only weekend warriors
# TODO explanations of symbols

# Direction ranges should be clockwise
SPOTS = [
  { id: 'kviljo-fs', 
    tekst: 'Kviljo eller Havika (kite, freestyle)', 
    wind: 8..15, 
    wind_dir: 'ESE'..'WNW' },
  { id: 'bausje-fs', 
    tekst: 'Bausje (kite, freestyle)', 
    wind: 8..15, 
    wind_dir: 'SE'..'NW' },
  { id: 'bispen-fs', 
    tekst: 'Bispen (kite, freestyle)', 
    wind: 8..15, 
    wind_dir: 'WSW'..'W' },
  { id: 'huseby-fs', 
    tekst: 'Huseby (kite, freestyle)', 
    wind: 8..15, 
    wind_dir: 'S'..'WSW' },
  { id: 'lomsesanden-fs', 
    tekst: 'Lomsesanden (kite, freestyle)', 
    wind: 8..15, 
    wind_dir: 'ESE'..'SSE' },

  { id: 'havika-w', 
    tekst: 'Havika (kite, bølger)', 
    wind: 10..20, 
    wind_dir: 'ESE'..'WSW', 
    wave: 2..5, 
    wave_dir: 'ESE'..'W' },
  { id: 'renna-w', 
    tekst: 'Pisserenna (kite, bølger)',
    wind: 12..25,
    wind_dir: 'WNW'..'NW',
    wave: 2.5..5,
    wave_dir: 'SW'..'NW' },
  { id: 'bua-w', 
    tekst: 'Litlerauna/Bua (kite, bølger)',
    wind: 12..25,
    wind_dir: 'WNW'..'NW',
    wave: 3..99,
    wave_dir: 'W'..'NW' },
  { id: 'blindgjengeren-w', 
    tekst: 'Militærområdet (kite, bølger)',
    wind: 12..25,
    wind_dir: 'SW'..'WSW',
    wave: 3..99,
    wave_dir: 'SW'..'WNW' },
  { id: 'vraket-w', 
    tekst: 'Vraket (Bausje vestodden) (kite, bølger)',
    wind: 12..25,
    wind_dir: 'SW'..'WSW',
    wave: 3..99,
    wave_dir: 'SW'..'WNW' },
  { id: 'lille-havika-w', 
    tekst: 'Lille Havika (kite, bølger)',
    wind: 12..25,
    wind_dir: 'SW'..'SW',
    wave: 2.5..5,
    wave_dir: 'SE'..'SW' },

  { id: 'renna-sup', 
    tekst: 'Pisserenna (SUP)',
    wind: 0..10,
    wave: 2.0..5,
    wave_dir: 'SW'..'NW' },
  { id: 'havika-sup', 
    tekst: 'Havika (SUP)', 
    wind: 0..10,
    wave: 2..5, 
    wave_dir: 'ESE'..'W' },
  { id: 'lille-havika-sup', 
    tekst: 'Lille Havika (SUP)',
    wind: 0..10,
    wave: 2.0..5,
    wave_dir: 'SE'..'SW' },
  { id: 'bua-sup', 
    tekst: 'Litlerauna/Bua (SUP)',
    wind: 0..10,
    wave: 2.5..99,
    wave_dir: 'W'..'NW' },
  { id: 'blindgjengeren-sup', 
    tekst: 'Militærområdet (SUP)',
    wind: 0..10,
    wind_dir: 'SW'..'WSW',
    wave: 2.5..99,
    wave_dir: 'SW'..'WNW' },
  { id: 'vraket-sup', 
    tekst: 'Vraket (Bausje vestodden) (SUP)',
    wind: 0..10,
    wind_dir: 'SW'..'WSW',
    wave: 2.5..99,
    wave_dir: 'SW'..'WNW' },
]

SUN_HOURS = {
  1 => 9..16,
  2 => 8..17,
  3 => 6..18,
  4 => 6..21,
  5 => 4..22,
  6 => 4..22,
  7 => 4..22,
  8 => 5..21,
  9 => 7..19,
  10 => 8..18,
  11 => 8..15,
  12 => 9..15
}

WIND_DIRS = %w(S SSW SW WSW W WNW NW NNW N NNE NE ENE E ESE SE SSE)
GURU = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), 'guru_data.yaml'))

def is_sunlight?(date, hours)
  SUN_HOURS[date.match(/\d\d\.(\d\d)\.\d\d\d\d/)[1].to_i].member? hours
end

def raining?(rain)
  rain >= 2.0
end


def wind_ok?(spot, wind)
  if spot[:wind]
    spot[:wind].member? wind
  else
    true
  end
end

def wave_ok?(spot, wave)
  if spot[:wave]
    spot[:wave].member? wave
  else
    true
  end
end

def direction_range_member?(range, dir)
  a, b, c = [range.begin, range.end, dir].map {|dd| WIND_DIRS.index(dd) }
  if a && b && c
    ((a <= c) && (c <= b) && (a <= b)) || (((c <= b) || (a <= c)) && (b < a))
  end
end

def wind_dir_ok?(spot, wind_dir)
  if spot[:wind_dir]
    direction_range_member? spot[:wind_dir], wind_dir
  else
    true
  end
end

def for_weekend_warrior?(date, time)
  if time >= 16
    true
  else
    d = Date.parse date
    (time >= 16) || (d.cwday >= 6) # sat = 6, sunday = 7
  end
end

def wave_dir_ok?(spot, wave_dir)
  if spot[:wave_dir]
    direction_range_member? spot[:wave_dir], wave_dir
  else
    true
  end
end

configure :production do
  require 'newrelic_rpm'
end

get '/' do
  erb :index
end

get '/report' do
  @all_spots = params['logikk'].match(/alle/)
  spots = SPOTS.select {|s| params['spots'][s[:id]] }

  if @all_spots
    @logikk_heading = 'Dager som passer for alle disse stedene på et gitt tidspunkt'
  else
    @logikk_heading = 'Dager som passer for noen disse stedene på et gitt tidspunkt'
  end

  @spot_navn = spots.map {|s| s[:tekst] }

  @hours = GURU.first[:d].keys

  @guru = GURU.map do |guru_day|
    results = guru_day[:d].map do |time, values|
      # check first for sunlight
      if not is_sunlight?(guru_day[:date], time) 
        :dark
      else
        # check for warm weather
        if values[:t] < 0
          :cold
        else
          if params['weekend'] and not for_weekend_warrior?(guru_day[:date], time)
            :not_weekend
          else
            if params['regn'] and raining?(values[:rain])
              :rain
            else
              results = spots.map do |spot|
                wind_ok?(spot, values[:wind]) && wind_dir_ok?(spot, values[:wind_dir]) &&
                  wave_ok?(spot, values[:wave]) && wave_dir_ok?(spot, values[:wave_dir]) 
              end
                
              ok = if @all_spots
                # all spots must match
                results.reduce &:"&"
              else
                # any spot will match
                results.reduce &:"|"
              end

              if ok
                :good
              else
                :bad
              end
            end
          end
        end
      end
    end
    { date: guru_day[:date], results: results }
  end

  erb :report
end
