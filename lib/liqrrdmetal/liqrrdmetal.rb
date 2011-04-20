# encoding: UTF-8
require 'strscan'

# Derived from the LiquidMetal[https://github.com/rmm5t/liquidmetal]
# JavaScript library, LiqrrdMetal brings substring scoring to Ruby.
# Similar to Quicksilver[http://qsapp.com/], LiqrrdMetal gives users the ability
# to quickly find the most relevant items by typing in portions of the string while
# seeing the portions of the substring that are being matched.
# 
# To facilitate common sorting, lower scores are _better_;
# a score of 0.0 indicates a perfect match, while a score of 1.0 indicates no match.
# 
# == Usage
# 
# Starting with the basics, here is how to find the score for a possible match:
# 
#  score = LiqqrdMetal.score( "re", "regards.txt" )
#  #=> 0.082
#     
#  score = LiqqrdMetal.score( "re", "preview.jpg" )
#  #=> 0.236
# 
#  score = LiqqrdMetal.score( "re", "no" )
#  #=> 1.0
# 
# Want to know which letters were matched?
# 
#  score,parts = LiqqrdMetal.score_with_parts( "re", "Preview.jpg" )
#  puts "%.02f" % score
#  #=> 0.24
# 
#  p parts
#  #=> [#<struct LiqrrdMetal::MatchPart text="P", match=false>,
#  #=>  #<struct LiqrrdMetal::MatchPart text="re", match=true>,
#  #=>  #<struct LiqrrdMetal::MatchPart text="view.jpg", match=false>]]
# 
#  puts parts.join
#  #=> Preview.jpg
# 
#  puts parts.map(&:to_html).join
#  #=> P<span class='match'>re</span>view.jpg
# 
#  require 'json'
#  puts parts.to_json
#  #=> [{"t":"P","m":false},{"t":"re","m":true},{"t":"view.jpg","m":false}]
# 
# Sort an array of possible matches by score, removing low-scoring items:
# 
#  def best_matches( search, strings )
#    strings.map{ |s|
#      [LiqrrdMetal.score(search,s),s]
#    }.select{ |score,string|
#      score < 0.3
#    }.sort.map{ |score,string|
#      string
#    }
#  end
# 
#  p best_matches( "re", various_filenames )
#  #=> ["resizing-text.svg", "PreviewIcon.psd" ]
# 
# Given an array of possible matches, return the matching parts sorted by score:
# 
#   hits = LiqrrdMetal.parts_by_score( "re", various_filenames )
# 
#   p hits.map(&:join)
#   #=> ["resizing-text.svg", "PreviewIcon.psd", "prime-finder.rb" ]
# 
#   p hits.map{ |parts| parts.map(&:to_ascii).join }
#   #=> ["_re_sizing-text.svg", "P_re_viewIcon.psd", "p_r_im_e_-finder.rb" ]
# 
# You can also specify the threshold for the parts_by_score method:
# 
#  good_hits = LiqrrdMetal.parts_by_score( "re", various_filenames, 0.3 )
# 
# 
# == License & Contact
# 
# LiqrrdMetal is released under the {MIT License}[http://www.opensource.org/licenses/mit-license.php].
# 
# Copyright (c) 2011, Gavin Kistner (!@phrogz.net)
module LiqrrdMetal
	VERSION = "0.6"

  # If you want score_with_parts to be accurate, the MATCH score must be unique
	MATCH                =  0.00  #:nodoc:
	NEW_WORD             =  0.01  #:nodoc:
	TRAILING_BUT_STARTED = [0.10] #:nodoc:
	BUFFER               = [0.15] #:nodoc:
	TRAILING             = [0.20] #:nodoc:
	NO_MATCH             = [1.00] #:nodoc:
	RE_CACHE             = {}     #:nodoc:

	# Used to identify substrings and whether or not they were matched directly by the search string.
	class MatchPart
		# The substring text
		attr_reader :text
		# Whether the substring was part of the match
		attr_reader :match
		def initialize( text, match=false )
			@text  = text
			@match = match
		end

		# Does this part indicate a matched substring?
		def match?;   @match; end

		# Returns the substring (regardless of whether it was matched or not)
		def to_s;     @text;  end

		# The text wrapped by the HTML <code>\&lt;span class='match'\&gt;...\&lt;/span\&gt;</code> (only wrapped if it was a match)
		#  score,parts = LiqqrdMetal.score_with_parts( "re", "Preview.jpg" )
		#  puts parts.map(&:to_html).join
		#  #=> P<span class='match'>re</span>view.jpg
		def to_html;  @match ? "<span class='match'>#{@text}</span>" : @text; end

		# The text wrapped with underscores (only wrapped if it was a match)
		#  score,parts = LiqqrdMetal.score_with_parts( "re", "Preview.jpg" )
		#  puts parts.map(&:to_ascii).join
		#  #=> P_re_view.jpg
		def to_ascii; @match ? "_#{@text}_" : text; end

		# Get this part as a terse JSON[http://json.org] payload suitable
		# for transmitting over the wire.
		#  require 'json'
		#  score,parts = LiqqrdMetal.score_with_parts( "re", "Preview.jpg" )
		#  puts parts.to_json
		#  #=> [{"t":"P","m":false},{"t":"re","m":true},{"t":"view.jpg","m":false}]

		def to_json(*a); { t:@text, m:!!@match }.to_json(*a); end
	end

	# Mixed into results for results_by_score
	module MatchResult
		# The text used to match against
		attr_accessor :liqrrd_match

		# The score for this result
		attr_accessor :liqrrd_score

		# Array of MatchPart instances
		attr_accessor :liqrrd_parts
	end

	module_function

	# Match a single search term against an array of objects,
	# using the supplied block to find the string to match against,
	# receiving an array of your objects with the MatchResult module mixed in.
	#
	# Non-matching entries (score of 1.0) will never be included in the results, no matter the value of score_threshold
	#
	#  User = Struct.new :name, :email, :id
	#  users = [ User.new( "Gavin Kistner",   "!@phrogz.net",          42 ),
	#            User.new( "David Letterman", "lateshow@pipeline.com", 17 ),
	#            User.new( "Scott Adams",     "scottadams@aol.com",    82 ) ]
	#  
	#  scom = LiqrrdMetal.results_by_score( "s.com", users ){ |user| user.email }
	#  #=> [#<struct User name="Scott Adams", email="scottadams@aol.com", id=82>,
	#  #=>  #<struct User name="David Letterman", email="lateshow@pipeline.com", id=17>]
	#  
	#  p scom.map{ |user| user.liqrrd_score }
	#  #=> [0.7222222222222222, 0.7619047619047619]
	#  
	#  p scom.map{ |user| user.liqrrd_parts.map(&:to_html).join }
	#  #=> ["<span class='match'>s</span>cottadams@aol<span class='match'>.com</span>",
	#  #=>  "late<span class='match'>s</span>how@pipeline<span class='match'>.com</span>"]
	def results_by_score( search, objects, score_threshold=1.0 )
		re = RE_CACHE[search] ||= /#{[*search.chars].join('.*?')}/i
		objects.map{ |o|
			m = yield(o)
			if m=~re
				score,parts = score_with_parts(search,m)
				if score<score_threshold
					o.extend MatchResult
					o.liqrrd_match = m
					o.liqrrd_score, o.liqrrd_parts = score,parts
					o
				end				
			end
		}.compact.sort_by{ |o|
			[ o.liqrrd_score, o.liqrrd_match ]
		}
	end

	# Match a single search term against an array of possible results,
	# receiving an array sorted by score (descending) of the matched text parts.
	#
	# Non-matching entries (score of 1.0) will never be included in the results, no matter the value of score_threshold
	#
	#  items = ["FooBar","Foo Bar","For the Love of Big Cars"]
	#  hits  = LiqrrdMetal.parts_by_score( "foobar", items )
	#  hits.each{ |parts| puts parts.map(&:to_ascii).join }
  #  #=> _FooBar_
  #  #=> _Foo_ _Bar_
  #  #=> _Fo_r the L_o_ve of _B_ig C_ar_s
	def parts_by_score( search, actuals, score_threshold=1.0 )
		re = RE_CACHE[search] ||= /#{[*search.chars].join('.*?')}/i
		actuals.map{ |actual|
			if actual=~re
				score,parts = score_with_parts(search,actual)
				if score<score_threshold
					[ actual, score, parts ]
				end
			end
		}.compact.sort_by{ |actual,score,parts|
			[ score, actual ]
		}.map{ |actual,score,parts|
			parts
		}
	end

	# Returns an array with the score of the match,
	# followed by an array of MatchPart instances.
	# 
	#  score, parts = LiqrrdMetal.score_with_parts( "foov", "A Fool in Love" )
	#  puts "%0.2f" % score
	#  #=> 0.46
	#  p parts.map{ |p| p.match? ? "_#{p}_" : p.text }.join
	#  #=> "A _Foo_l in Lo_v_e"
	#  p parts.map(&:to_html).join
	#  #=> "A <span class='match'>Foo</span>l in Lo<span class='match'>v</span>e"
	def score_with_parts( search, actual )
		re = RE_CACHE[search] ||= /#{[*search.chars].join('.*?')}/i
		if search.length==0
			[ TRAILING[0], [MatchPart.new(actual)] ]
		elsif (search.length > actual.length) || (search !~ re)
			[ NO_MATCH[0], [MatchPart.new(actual)] ]
		else
			values = letter_scores( search, actual )
			score  = values.inject{ |sum,score| sum+score } / values.length
			was_matching,start = nil
			parts = []
			values.each_with_index do |score,i|
				is_match = score==MATCH
				if is_match != was_matching
					parts << MatchPart.new(actual[start...i],was_matching) if start
					was_matching = is_match
					start = i
				end
			end
			parts << MatchPart.new(actual[start..-1],was_matching) if start
			[ score, parts ]
		end
	end
	
	# Returns an array of score/string tuples, sorted by score, below the <code>score_threshold</code>
	#
	# Non-matching entries (score of 1.0) will never be included in the results, no matter the value of <code>score_threshold</code>
	def sorted_with_scores( search, actuals, score_threshold=1.0 )
		if search.length==0
			[]
		else
			re = RE_CACHE[search] ||= /#{[*search.chars].join('.*?')}/i			
			actuals.map{ |actual|
				if actual=~re
					values = letter_scores( search, actual )
					score = values.inject{ |sum,score| sum+score } / values.length					
					[score,actual] if score < score_threshold
				end
			}.compact.sort
		end
	end

	# Return a score for matching the search term against the actual text.
	# A score of <code>1.0</code> indicates no match. A score of <code>0.0</code> is a perfect match.
	def score( search, actual )
		re = RE_CACHE[search] ||= /#{[*search.chars].join('.*?')}/i
		if search.length==0
			TRAILING[0]
		elsif (search.length > actual.length) || (search !~ re)
			NO_MATCH[0]
		else
			values = letter_scores( search, actual )
			values.inject{ |sum,score| sum+score } / values.length
		end
	end

	# Return an aray of scores for each letter in the actual text.
	# Returns a single-value array of <code>[0.0]</code> if no match exists.
	def letter_scores( search, actual )
		actual_length = actual.length
		scores = Array.new(actual_length)

		last = -1
		started = false
		scanner = StringScanner.new actual
		search.chars.each do |c|
			return NO_MATCH unless fluff = scanner.scan_until(/#{Regexp.escape c}/i)
			pos = scanner.pos-1
			started = true if pos == 0
			if /\s/ =~ actual[pos-1]
				scores[pos-1] = NEW_WORD unless pos==0
        scores[(last+1)..(pos-1)] = BUFFER*(fluff.length-1)
			elsif /[A-Z]/ =~ actual[pos]
				scores[(last+1)..pos] = BUFFER*fluff.length
			else
				scores[(last+1)..pos] = NO_MATCH*fluff.length
			end
			scores[pos] = MATCH
			last = pos
		end
		scores[ (last+1)...scores.length ] = (started ? TRAILING_BUT_STARTED : TRAILING) * (scores.length-last-1)
		scores
	end
end