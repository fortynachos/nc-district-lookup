######################################
# 
# NC Bulk District Lookup Tool
# Author: michael.fotinatos@gmail.com
# 
# This is currently written to pull
# state senate districts.  It can
# easily be modified for other lookups
#
#######################################

# TODO: Make logging less verbose

#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'logger'
require 'optparse'
require 'httparty'
require 'csv'
require 'uri-handler'
require 'pry'

logger = Logger::new(STDERR)

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bulk_district_lookup.rb [options]"

  opts.on("-f n", "--file", "CSV Import File") do |f|
    options[:file] = f
  end

  opts.on("-d n", "--debug", "Enables HTTP debugger") do |d|
    options[:debug] = d
  end 
end.parse!

# Read File from Path
file_contents = CSV.parse(File.read(options[:file]), headers: true)

CSV.open("./district_output.csv", "w") do |csv|  
  csv << ["contact_id", "full_address", "x_coord", "y_coord", "old_district_number", "old_district_rep", "new_district_number"]
end  

file_contents.each do |row| 
  endpoint_url = "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates?SingleLine=#{row['full_address'].to_uri}&f=json&outSR=%7B%22latestWkid%22%3A3857%2C%22wkid%22%3A102100%7D&outFields=DisplayX%2C%20DisplayY%2C%20StAddr%2C%20City%2C%20RegionAbbr%2C%20Postal%2C%20PostalExt&searchExtent=%7B%22spatialReference%22%3A%7B%22wkid%22%3A3857%7D%2C%22xmin%22%3A-9400000%2C%22ymin%22%3A3960000%2C%22xmax%22%3A-8350000%2C%22ymax%22%3A4400000%7D&category=Subaddress%2CStreet%20Address%2CPoint%20Address&countryCode=US&maxLocations=6"
  
  response = HTTParty.get(
	  endpoint_url,
	  logger: logger, log_level: :info, log_format: :apache,
  )

  x_coord = JSON.parse(response.body)["candidates"][0]["attributes"]["DisplayX"]
  y_coord = JSON.parse(response.body)["candidates"][0]["attributes"]["DisplayY"]

  def get_district_endpoint(year, x_coord, y_coord)
    district_endpoint_url = "https://services5.arcgis.com/gRcZqepTaRC6tVZL/arcgis/rest/services/NCGA_Senate_#{year}/FeatureServer/0/query?f=json&geometry=%7B%22spatialReference%22%3A%7B%22wkid%22%3A4326%7D%2C%22x%22%3A#{x_coord}%2C%22y%22%3A#{y_coord}%7D&outFields=*&spatialRel=esriSpatialRelIntersects&geometryType=esriGeometryPoint&inSR=4326&outSR=4326"
  end

  old_district_response = HTTParty.get(
    get_district_endpoint("2018", x_coord, y_coord),
    logger: logger, log_level: :info, log_format: :apache,
  )

  old_district_number = JSON.parse(old_district_response)["features"][0]["attributes"]["sDistrict"]
  old_district_rep = JSON.parse(old_district_response)["features"][0]["attributes"]["sPreferredName"]

  new_district_response = HTTParty.get(
    get_district_endpoint("2019", x_coord, y_coord),
    logger: logger, log_level: :info, log_format: :apache,
  )

  new_district_number = JSON.parse(new_district_response)["features"][0]["attributes"]["District"]

  CSV.open("./district_output.csv", "a") do |csv|  
    csv << [row["contact_id"], row["full_address"], x_coord, y_coord, old_district_number, old_district_rep, new_district_number]
  end  
end
