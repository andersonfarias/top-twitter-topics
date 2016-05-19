require "sinatra"
require "sinatra/base"
require "sinatra/json"
require "sinatra/config_file"
require 'rufus-scheduler'
require "./tasks/top_tweets.rb"

class TweetPooling < Sinatra::Base
	register Sinatra::ConfigFile
	register Sinatra::ActiveRecordExtension

	config_file './config/app.yml'

	def self.schedule_tweet_tasks( pooling, search )
		scheduler = Rufus::Scheduler.new

		scheduler.every pooling[ :frequency ], { :overlap => false, :timeout => pooling[ :timeout ] } do
			begin
				task = TopTwitterTask.new
				task.execute search[ :topics ], search[ :limit ]
			rescue Rufus::Scheduler::TimeoutError
				puts "Took too long to find the tweets, so we're giving up this time."
			end
		end
	end

	configure do
		schedule_tweet_tasks settings.pooling, settings.search
	end

	get '/tweets' do

		topic = params[ :name ]

		if topic.nil?
			return json :error => 'Missing topic!'			
		end

		if not settings.search[ :topics ].include? topic
			return json :error => 'Invalid topic! The valid topics are #{settings.search[ :topics ]}'
		end

		json :tweets => Tweet.order( 'updated_at desc' ).limit( settings.search[ :limit ] ).find_by( :topic => topic )
	end

	# start the server if ruby file executed directly
	run! if app_file == $0
end