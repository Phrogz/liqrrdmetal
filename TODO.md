# Features

* Try dropping StringScanner in favor of regex-only: http://stackoverflow.com/questions/5718761/find-consecutive-substring-indexes/5719098#5719098

* Mix 'parts' directly into string results?

* Drop `to_html` and `to_ascii` as being inappropriately view-centric?

# Issues

* There are too many scattered methods with similar signatures and functionality and non-DRY sections. Merge.

* Why does the "Tegra" item sort before "gk10x"? Starting with the string should weigh in favorably.
    
        irb> LiqrrdMetal.sorted_with_scores( "gkis", %w[ Tegra_Keenhigh_Support gk10x-DFT-insertion ] )
        #=> [[0.3681818181818182, "Tegra_Keenhigh_Support"], [0.5052631578947367, "gk10x-DFT-insertion"]]

* Early occurrences of leading letters are favored over larger chunks:

        irb> puts LiqrrdMetal.score_with_parts( "low", "Follow" ).last.map(&:to_html).join
        #=> Fo<span class='match'>l</span>l<span class='match'>ow</span>

  Perhaps try (horror of horrors) creating n variations, splitting into smaller and smaller chunks, before ending
  at `/(e).*?(a).*?(c).*?(h).*?(l).*?(e).*?(t).*?(t).*?(e).*?(r)/i`?