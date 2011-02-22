# application_controller.rb
# MacRubyLyrics
#
# Created by Johannes Fahrenkrug on 11.02.11.
# Copyright 2011 Springenwerk. All rights reserved.

require 'open-uri'
require 'cgi'
require 'json'

framework "WebKit"

class SongController	
	attr_accessor :webView, :artistField, :songField, :button, :textView
	
	def loadSong(sender)
		enableFields(false)
		textView.selectedRange = NSMakeRange(0, 0)
		textView.string = "Searching..."
		
		speechSynthesizer.stopSpeaking
		artist = CGI::escape(artistField.stringValue)
		song = CGI::escape(songField.stringValue)
		apiURL = "http://lyrics.wikia.com/api.php?fmt=json&artist=#{artist}&song=#{song}"
		
		# Load the JSON asynchronously
		Thread.new do
			songAttributes = open(apiURL) do |f|
				# make JSON valid
				jsonString = f.string.gsub(/\Asong\s\=\s/, '').gsub("\"", "\\\"").gsub("\'", "\"")
				JSON.parse(jsonString)
			end
			
			self.performSelectorOnMainThread('loadSongPage:', withObject:songAttributes, waitUntilDone:false)
		end
	end
	
	# WebFrameLoadDelegate methods
	def webView(webView, didFinishLoadForFrame:aWebFrame)
		if aWebFrame == webView.mainFrame
			NSLog(webView.stringByEvaluatingJavaScriptFromString("document.innerText"))
			lyrics = webView.stringByEvaluatingJavaScriptFromString("document.getElementsByClassName('lyricbox')[0].innerText")
			# Remove ads by deleting first and last lines
			lyrics = lyrics.strip.gsub(/(\A.*$)|(.*\z)/, '')
			textView.string = lyrics
			
			speechSynthesizer.startSpeakingString(lyrics)
			enableFields(true)
		end
	end
	
	# NSSpeechSynthesizerDelegate methods
	def speechSynthesizer(speechSynthesizer, willSpeakWord:wordRange, ofString:aString)
		textView.selectedRange = wordRange
	end
	
	private
	
	def loadSongPage(songAttributes)
		if songAttributes['lyrics'] == 'Not found'
			textView.string = "Sorry, couldn't find that song."
			enableFields(true)
		else
			textView.string = "Getting lyrics for '#{songAttributes['song']}' by #{songAttributes['artist']}..."
			webView.mainFrameURL = songAttributes['url']
		end
	end
	
	def speechSynthesizer
		unless @speechSynthesizer
			@speechSynthesizer = NSSpeechSynthesizer.new
			@speechSynthesizer.delegate = self
			@speechSynthesizer.voice = "com.apple.speech.synthesis.voice.Alex"
		end
		
		@speechSynthesizer
	end
	
	def enableFields(yn)
		artistField.enabled = yn
		songField.enabled = yn
		button.enabled = yn
	end
end