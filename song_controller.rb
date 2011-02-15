# application_controller.rb
# MacRubyLyrics
#
# Created by Johannes Fahrenkrug on 11.02.11.
# Copyright 2011 Springenwerk. All rights reserved.

require 'open-uri'
require 'cgi'
require 'json'

framework "WebKit"

class SongController < NSWindowController
	LYRICS_API = "http://lyrics.wikia.com/api.php?fmt=json&"
	
	attr_accessor :webView, :artistField, :songField, :textView
	
	def loadSong(sender)
		NSLog("clicked " + webView.class.to_s)
		textView.string = "Searching..."
		
		speechSynthesizer.stopSpeaking
		apiURL = LYRICS_API + "artist=#{CGI::escape(artistField.stringValue)}&song=#{CGI::escape(songField.stringValue)}"
		NSLog(apiURL)
		
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
			NSLog("did finish...")
			NSLog(webView.stringByEvaluatingJavaScriptFromString("document.innerText"))
			lyrics = webView.stringByEvaluatingJavaScriptFromString("document.getElementsByClassName('lyricbox')[0].innerText")
			# Remove ads by deleting first and last lines
			lyrics = lyrics.strip.gsub(/(\A.*$)|(.*\z)/, '')
			textView.string = lyrics
			
			speechSynthesizer.startSpeakingString(lyrics)
		end
	end
	
	# NSSpeechSynthesizerDelegate methods
	def speechSynthesizer(speechSynthesizer, willSpeakWord:wordRange, ofString:aString)
		textView.selectedRange = wordRange
	end
	
	private
	
	def loadSongPage(songAttributes)
		textView.string = "Getting lyrics for '#{songAttributes['song']}' by #{songAttributes['artist']}..."
		webView.preferences = webPreferences
		webView.frameLoadDelegate ||= self
		webView.mainFrameURL = songAttributes['url']
	end
	
	def speechSynthesizer
		if !defined?(@speechSynthesizer)
			@speechSynthesizer = NSSpeechSynthesizer.new
			@speechSynthesizer.delegate = self
			@speechSynthesizer.voice = "com.apple.speech.synthesis.voice.Alex"
		end
		
		@speechSynthesizer
	end
	
	def webPreferences
		if !defined?(@webPreferences)
			# No Flash and no images
			@webPreferences = WebPreferences.standardPreferences
			@webPreferences.plugInsEnabled = false
			@webPreferences.loadsImagesAutomatically = false
		end
	
		@webPreferences
	end
end