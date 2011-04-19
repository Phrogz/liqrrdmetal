## About LiqqrdMetal

Derived from the [LiquidMetal](https://github.com/rmm5t/liquidmetal)
JavaScript library, LiqrrdMetal brings substring scoring to Ruby.
Similar to [Quicksilver](http://qsapp.com/), LiqrrdMetal gives users the ability
to quickly find the most relevant items by typing in portions of the string, while
seeing the portions of the substring that are being matched.

To facilitate common sorting, lower scores are _better_;
a score of 0.0 indicates a perfect match, while a score of 1.0 indicates no match.


## Usage

Starting with the basics, here is how to find the score for a possible match:

    score = LiqqrdMetal.score( "re", "regards.txt" )
    #=> 0.082
    
    score = LiqqrdMetal.score( "re", "preview.jpg" )
    #=> 0.236

    score = LiqqrdMetal.score( "re", "no" )
    #=> 1.0

Want to know which letters were matched?

    score,parts = LiqqrdMetal.score_with_parts( "re", "Preview.jpg" )
    puts "%.02f" % score
    #=> 0.24

    p parts
    #=> [#<struct LiqrrdMetal::MatchPart text="P", match=false>,
    #=>  #<struct LiqrrdMetal::MatchPart text="re", match=true>,
    #=>  #<struct LiqrrdMetal::MatchPart text="view.jpg", match=false>]]

    puts parts.join
    #=> Preview.jpg

    puts parts.map(&:to_html).join
    #=> P<span class='match'>re</span>view.jpg

    require 'json'
    puts parts.to_json
    #=> [{"t":"P","m":false},{"t":"re","m":true},{"t":"view.jpg","m":false}]

Sort an array of possible matches by score, removing low-scoring items:

    def best_matches( search, strings )
      strings.map{ |s|
        [LiqrrdMetal.score(search,s),s]
      }.select{ |score,string|
        score < 0.3
      }.sort.map{ |score,string|
        string
      }
    end

    p best_matches( "re", various_filenames )
    #=> ["resizing-text.svg", "PreviewIcon.psd" ]

Given an array of possible matches, return the matching parts sorted by score:

    hits = LiqrrdMetal.parts_by_score( "re", various_filenames )

    p hits.map(&:join)
    #=> ["resizing-text.svg", "PreviewIcon.psd", "prime-finder.rb" ]

    p hits.map{ |parts| parts.map(&:to_ascii).join }
    #=> ["_re_sizing-text.svg", "P_re_viewIcon.psd", "p_r_im_e_-finder.rb" ]

    require 'json'
    puts hits[1].to_json
    #=> [{"t":"P","m":false},{"t":"re","m":true},{"t":"viewIcon.psd","m":false}]

You can also specify the threshold for the `parts_by_score` method:

    good_hits = LiqrrdMetal.parts_by_score( "re", various_filenames, 0.3 )

Finally, you probably have additional information you want to go along with each string,
such as a database row id or tooltip you want to display along with it. For this, pass a block
to `results_by_score` that accepts one of the objects in your array and returns the string to
filter against:

    User = Struct.new :name, :email, :id
    users = [ User.new( "Gavin Kistner",   "!@phrogz.net",          42 ),
              User.new( "David Letterman", "lateshow@pipeline.com", 17 ),
              User.new( "Scott Adams",     "scottadams@aol.com",    82 ) ]
    
    scom = LiqrrdMetal.results_by_score( "s.com", users ){ |user| user.email }
    #=> [#<struct User name="Scott Adams", email="scottadams@aol.com", id=82>,
    #=>  #<struct User name="David Letterman", email="lateshow@pipeline.com", id=17>]
    
    p scom.map{ |user| user.liqrrd_score }
    #=> [0.7222222222222222, 0.7619047619047619]
    
    p scom.map{ |user| user.liqrrd_parts.map(&:to_html).join }
    #=> ["<span class='match'>s</span>cottadams@aol<span class='match'>.com</span>",
    #=>  "late<span class='match'>s</span>how@pipeline<span class='match'>.com</span>"]



## License & Contact

LiqrrdMetal is released under the [MIT License](http://www.opensource.org/licenses/mit-license.php).

Copyright (c) 2011, Gavin Kistner (!@phrogz.net)

