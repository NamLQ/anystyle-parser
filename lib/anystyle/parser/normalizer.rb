module Anystyle
	module Parser

		class Normalizer

			include Singleton

			def method_missing(name, *arguments, &block)
				case name.to_s
				when /^normalize_(.+)$/
					normalize($1.to_sym, *arguments, &block)
				else
					super
				end
			end

			# Default normalizer. Strips punctuation.
			def normalize(key, hash)
				token, *dangling =  hash[key]
				unmatched(key, hash, dangling) unless dangling.empty?

				token.gsub!(/^\W+|\W+$/, '')
				hash[key] = token
				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_author(hash)
				authors, *dangling = hash[:author]
				unmatched(:author, hash, dangling) unless dangling.empty?
				
				if authors =~ /\W*[Ee]d(s|itors)?\W*$/ && !hash.has_key?(:editor)
					hash[:editor] = hash.delete(:author)
					normalize_editor(hash)
				else
		      hash[:etal] = true if !!authors.sub!(/\bet\.?\s*al.*$/i, '')
					authors.gsub!(/^\W+|\W+$/, '')
					hash[:author] = normalize_names(authors)
				end
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
	    def normalize_editor(hash)
	      editors, edition = hash[:editor]
	
				unless edition.nil?
					if edition =~ /(\d+)/
						hash[:edition] = $1.to_i
					end
				end
	
				editors.gsub!(/^\W+|\W+$/, '')
				editors.gsub!(/^in\s+/i, '')
				editors.gsub!(/\W*[Ee]d(s|itors)?/, '')
				
	      hash[:editor] = normalize_names(editors)
	      hash
			rescue => e
				warn e.message
				hash
	    end

			def normalize_translator(hash)
				translators = hash[:translator]
				
				translators.gsub!(/^\W+|\W+$/, '')
				translators.gsub!(/\W*trans(lated)?\W*/i, '')
				translators.gsub!(/ by /i, '')
				
				hash[:translator] = normalize_names(translators)
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_names(names)
				names = tokenize_names(names).map do |name|
					name.strip!
					name.gsub!(/\b([[:upper:]])(\W|$)/) { [$1, $2 == ?. ? nil : ?., $2].compact.join }
					name
				end
				names.join(' and ')
			rescue => e
				warn e.message
				hash
			end
			
			def tokenize_names(names)
				s, n, ns, cc = StringScanner.new(names), '', [], 0
				until s.eos?
					case
					when s.scan(/\s+/)
						n << ' '
					when s.scan(/and\b|&/)
						ns << n
						n, cc = '', 0
					when s.scan(/,?\s*(jr|sr|ph\.?d|m\.?d|esq)\.?/i)
						n << s.matched
					when s.scan(/,/)
						if cc > 0
							ns << n
							n, cc = '', 0							
						else
							n << s.matched
							cc += 1
						end
					when s.scan(/\w+/), s.scan(/./)
						n << s.matched
					end
				end
				ns << n		
			end
			
			def normalize_title(hash)
				title, container = hash[:title]
				
				unless container.nil?
					hash[:container] = container
					normalize(:container, hash)
				end

				extract_edition(title, hash)
				
				title.gsub!(/[\.,:;\s]+$/, '')
				hash[:title] = title
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def extract_edition(token, hash)
				if token.gsub!(/\W*(\d+)(?:st|nd|rd|th)?\s*ed(?:ition|\.)?\W*/i, '')
					hash[:edition] = $1.to_i
				end				
			end
			
			def normalize_booktitle(hash)
				booktitle, *dangling = hash[:booktitle]
				unmatched(:booktitle, hash, dangling) unless dangling.empty?
				
				booktitle.gsub!(/^in\s*/i, '')

				extract_edition(booktitle, hash)

				booktitle.gsub!(/[\.,:;\s]+$/, '')			
				hash[:booktitle] = booktitle
				
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_container(hash)
				container, *dangling = hash[:container]
				unmatched(:container, hash, dangling) unless dangling.empty?
				
				case container
				when /dissertation abstracts/i
					container.gsub!(/\s*section \w: ([\w\s]+).*$/i, '')
					hash[:category] = $1 unless $1.nil?
					hash[:type] = :phdthesis
				end
				
				hash[:container] = container
				hash
			rescue => e
				warn e.message
				hash
			end
			
			def normalize_date(hash)
				date, *dangling = hash[:date]
				unmatched(:date, hash, dangling) unless dangling.empty?
				
				case date
				when /(\d{4})/
					hash[:year] = $1.to_i
					hash.delete(:date)
				end

				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_volume(hash)
				volume, *dangling = hash[:volume]
				unmatched(:volume, hash, dangling) unless dangling.empty?
				
				case volume
				when /\D*(\d+)\D+(\d+[\s&-]+\d+)/
					hash[:volume], hash[:number] = $1.to_i, $2
				when /\D*(\d+)\D+(\d+)/
					hash[:volume], hash[:number] = $1.to_i, $2.to_i
				when /(\d+)/
					hash[:volume] = $1.to_i
				end

				hash
			rescue => e
				warn e.message
				hash
			end

			def normalize_pages(hash)
				pages, *dangling = hash[:pages]
				unmatched(:pages, hash, dangling) unless dangling.empty?
				
				# "volume.issue (year):pp"
				case pages
				when /(\d+) (?: \.(\d+))? (?: \( (\d{4}) \))? : (\d.*)/x
					hash[:volume] = $1.to_i
					hash[:number] = $2.to_i unless $2.nil?
					hash[:year] = $3.to_i unless $3.nil?
					hash[:pages] = $4
				end

				case hash[:pages]
				when /(\d+)\D+(\d+)/
					hash[:pages] = [$1,$2].join('--')
				when  /(\d+)/
					hash[:pages] = $1
				end
				
				hash
			rescue => e
				warn e.message
				hash
			end

			private
			
			def unmatched(label, hash, tokens)
				hash["unmatched-#{label}"] = tokens.join(' ')
			end
			
		end

	end
end