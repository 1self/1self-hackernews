require 'hnrb'

hn = HNrb::APIWrapper.new

m = hn.get_user("strttn")

puts m
