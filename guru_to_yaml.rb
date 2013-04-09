require 'yaml'
require 'nokogiri'
require 'open-uri'

guru_url = 'http://www.windguru.cz/int/historie.php?id_georegion=150&id_zeme=578&id_region=0&mis_spot=125&search=&id_typspot[2]=2&id_typspot[4]=4&id_typspot[3]=3&id_typspot[10]=10&id_typspot[8]=8&id_typspot[9]=9&id_typspot[11]=11&mis_fav=0&id_spot=125&odden=1&odmes=1&odrok=2012&doden=31&domes=12&dorok=2012&tj=c&wj=ms&step=3&pwindspd=1&psmer=1&phtsgw=1&pwavesmer=1&ptmp=1&papcp=1&pmwindspd=1&odeslano=1&model=gfs'

days = []

(2006..2012).each do |year|
  doc = Nokogiri::HTML(open(guru_url.gsub(/2012/, year.to_s)))
  doc.css('tr').each do |tr|
    cells = tr.css('td').map {|td| td.css('img').first['alt'] rescue td.content }

    if cells.size == 49 && cells.first.match(/\d\d\.\d\d\.\d\d\d\d/)
      date = cells.shift
      wind_speeds = cells[0..7].map(&:to_f)
      wind_dirs = cells[8..15]
      wave_heights = cells[16..23].map(&:to_f)
      wave_dirs = cells[24..31].map {|wd| wd.match(/[A-Z]/) && wd  }
      temperatures = cells[32..39].map(&:to_f)
      rains = cells[40..47].map(&:to_f)

      data = Hash[[2, 5, 8, 11, 14, 17, 20, 23].zip(wind_speeds.zip(wind_dirs, wave_heights, wave_dirs, temperatures, rains).map do |dd| 
        Hash[[:wind, :wind_dir, :wave, :wave_dir, :t, :rain].zip dd]
      end)]

      days << {:date => date, :d => data}
    end
  end
end

File.open 'guru_data.yaml', 'w' do |yaml|
  yaml.write YAML::dump days
end
