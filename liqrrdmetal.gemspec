# encoding: UTF-8
require File.join(File.dirname(__FILE__),'lib/liqrrdmetal')
Gem::Specification.new do |s|
	s.name        = "liqrrdmetal"
	s.version     = LiqrrdMetal::VERSION
	s.date        = "2011-04-19"
	s.authors     = ["Gavin Kistner"]
	s.email       = "gavin@phrogz.net"
	s.homepage    = "http://github.com/Phrogz/liqrrdmetal"
	s.summary     = "Calculate scoring of autocomplete-style substring matches."
	s.description = "Derived from the LiquidMetal JavaScript library, LiqrrdMetal brings substring scoring to Ruby. Similar to Quicksilver, LiqrrdMetal gives users the ability to quickly find the most relevant items by typing in portions of the string, while seeing the portions of the substring that are being matched."
	s.files       = %w[ lib/**/* ].inject([]){ |all,glob| all+Dir[glob] }
	s.requirements << "StringScanner (part of the Ruby Standard Library)"
	s.has_rdoc = true
end
