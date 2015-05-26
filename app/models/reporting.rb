module Moped
	class Collection
		def aggregate(pipeline, opts = {})
			database.session.command({aggregate: name, pipeline: pipeline}.merge(opts))["result"]
		end
	end
end

class Reporting

	def self.sod(date)
		Time.utc(date.year, date.month, date.day,0,0,0)
	end

	def self.eod(date)
    Time.utc(date.year, date.month, date.day,0,0,0) + 1.day
	end

	def self.update_reporting(start_date=Time.now, end_date=Time.now, merge=true)
		start_date = self.sod(start_date)
		end_date = self.eod(end_date)
		
		# p "from: #{start_date} to: #{end_date}"

		map = %Q{
			function() {
			    var datetime = new Date(this.created_at);
			    var created_at_day = new Date(Date.UTC(datetime.getUTCFullYear(),
			                                     datetime.getUTCMonth(),
			                                     datetime.getUTCDate()));

				if(this.hasOwnProperty("resource") && this.resource!=null)
					recommended = this.resource.hasOwnProperty("recommended") ? this.resource.recommended : null;
				else
					recommended = null;

			    var value = {
				    data: [
				      {
				      sess: this.session_id,
				      lang: this.language,
				      recommendation: this.recommendation_enabled,
				      ab_group: this.ab_group,
				      recommended: recommended,
				      algorithm: this.algorithm
				      }
				    ]
			    };

			    emit(created_at_day, value);
			}
		}

		reduce = %Q{
			function(key, values) {
			  var reduced = {"data":[]};;
			  for (var i in values)
			  {
			  	var inter = values[i];
				for (var j in inter.data) {
			    	reduced.data.push(inter.data[j]);
				}
			  }

			  return reduced;
			}
		}

		final = %Q{
			function(key, reduced)
			{
				var final = {visits: {total: 0, all: 0, control: 0, control700: 0 }, reads: {total: 0, all: 0, control: 0, control700: 0}, avg: {all: 0, control: 0, control700: 0}, langs: {}, recommendation: {enabled: 0, disabled: 0}, algorithms: {}, recommended: {yes: 0, no: 0}};
				var visits_all = [];
				var visits_control = [];
				var visits_control700 = [];
				var visits_total = [];
				var langs = {};
				var algorithms = {};
				for(var i in reduced.data)
				{
					final.reads.total += 1;

					var session = reduced.data[i].sess;
					if(reduced.data[i].ab_group=='C')
					{
						final.reads.control700 += 1;
					    if (visits_control700.indexOf(session)==-1) visits_control700.push(session);
					}
					else if(reduced.data[i].ab_group=='B')
					{
						final.reads.control += 1;
					    if (visits_control.indexOf(session)==-1) visits_control.push(session);
					} else {
						final.reads.all += 1;
					    if (visits_all.indexOf(session)==-1) visits_all.push(session);
					}

				    if (visits_total.indexOf(session)==-1)
				    {
				    	visits_total.push(session);

				    	if(reduced.data[i].recommendation==1)
			    			final.recommendation.enabled+=1;
		    			else
			    			final.recommendation.disabled+=1;
				    }

				    var lang = reduced.data[i].lang;
				    var keys = Object.keys(langs);
				    if(keys.indexOf(lang)==-1)
			    		langs[lang]=1;
			    	else
			    		langs[lang]+=1;

		    		if(reduced.data[i].recommended=="true")
		    		{
		    			final.recommended.yes += 1;
		    			algorithm = reduced.data[i].algorithm;
		    			keys = Object.keys(algorithms);
		    			if (algorithm!=null)
		    			{
					    	if(keys.indexOf(algorithm)==-1)
					    		algorithms[algorithm]=1;
					    	else
					    		algorithms[algorithm]+=1;
		    			}
		    		}
		    		else
		    		{
		    			if(reduced.data[i].recommendation==1)
		    				final.recommended.no += 1;
		    		}
				}

				final.visits.all = visits_all.length;
				final.visits.control = visits_control.length;
				final.visits.control700 = visits_control700.length;
				final.visits.total = visits_total.length;

				final.avg.all = final.visits.all==0 ? 0 : Math.round(100*final.reads.all/final.visits.all)/100;
				final.avg.control = final.visits.control==0 ? 0 : Math.round(100*final.reads.control/final.visits.control)/100;
				final.avg.control700 = final.visits.control700==0 ? 0 : Math.round(100*final.reads.control700/final.visits.control700)/100;
				final.langs = langs;
				final.algorithms = algorithms;

				final.recommendation.enabled = Math.round(final.recommendation.enabled*1000/(final.visits.total))/10;
				final.recommendation.disabled = Math.round(final.recommendation.disabled*1000/(final.visits.total))/10;

				return final;
			}
		}

		# must iterate through each doc to save new collection
		if merge
			Activity.where(:created_at.gte => start_date, :created_at.lt => end_date, :activity => 'read').map_reduce(map, reduce).out(merge: "reporting").finalize(final).each do |doc|
				puts doc
			end
		else
			Activity.where(:created_at.gte => start_date, :created_at.lt => end_date, :activity => 'read').map_reduce(map, reduce).out(replace: "reporting").finalize(final).each do |doc|
				puts doc
			end
		end
	end

  def self.get_standard_chart(start_date=nil, end_date=nil, options={})
    start_date ||= 7.days.ago
    end_date ||= Time.now
    start_date = start_date.strftime('%Y%m%d').to_i
    end_date = end_date.strftime('%Y%m%d').to_i
    session = Mongoid.default_session
    collection = options[:collection] || :reporting_std
    where = options[:where] || {'_id' => {'$gte' => start_date, '$lte' => end_date}}

    data = {'sessions'=>{}}
    interval = session[collection].find(where).sort({"_id" => 1})
    interval.each do |doc|
      dt = Date.strptime(doc['_id'].to_s,'%Y%m%d').strftime('%F')
      # puts "#{doc['_id']} => #{dt}"
      doc['activities'].each do |activity|
        data[activity['activity']] = {} unless data.has_key? activity['activity']
        data[activity['activity']][dt] = activity['count']
      end
      data['sessions'][dt] = doc['sessions']
    end
    result = []
    data.keys.each do |key|
      result << {name: key, data: data[key]}
    end
    result
  end

  def self.get_weekly_chart(start_date=nil, end_date=nil, options={})
    start_date ||= 7.days.ago
    end_date ||= Time.now
    start_date = start_date.strftime('%Y%m%d').to_i
    end_date = end_date.strftime('%Y%m%d').to_i
    session = Mongoid.default_session
    collection = options[:collection] || :reporting_std
    current_date = end_date
    data = {}
    while current_date >= start_date
      _current = Date.parse(current_date.to_s)
      current_start = (_current - 6.days).strftime('%Y%m%d').to_i
      where = options[:where] || {'_id' => {'$gte' => current_start, '$lte' => current_date}}

      interval = session[collection].find(where)
      counts = {users: 0, sessions: 0}
      interval.each do |doc|
        counts[:users] += doc['users']
        counts[:sessions] += doc['sessions']
      end

      data[_current] = counts[:users]==0 ? 0 : (counts[:sessions].to_f/counts[:users].to_f).round(3)

      _current -= 1.day
      current_date = _current.strftime('%Y%m%d').to_i
    end

    data
	end

	def self.get_metric_chart(start_date=nil, end_date=nil, options={})
		start_date ||= 7.days.ago
		end_date ||= Time.now
		start_date = start_date.strftime('%Y%m%d').to_i
		end_date = end_date.strftime('%Y%m%d').to_i
		_data = {}
		Mongoid.default_session[options[:collection]].find({'_id' => {'$gte' => start_date, '$lte' => end_date}}).sort({'_id'=>1}).each do |doc|
			doc['data'].keys.each do |key|
				_data[key]||={}
				unless options[:metric]
					_data[key][Date.parse(doc['_id'].to_s).in_time_zone] = doc['data'][key] if doc['data'][key]
				else
					_data[key][Date.parse(doc['_id'].to_s).in_time_zone] = doc['data'][key][options[:metric]] if doc['data'][key][options[:metric]]
				end
			end
		end

		data=[]
		_data.keys.each do |key|
			data << {name: key, data: _data[key]}
		end
		data
	end

	def self.get_chart_data(start_date=nil, end_date=nil, type=nil, options={})
		start_date ||= 7.days.ago
		end_date ||= Time.now
		start_date = Reporting.sod(start_date)
		end_date = Reporting.eod(end_date)
		session = Mongoid.default_session
		collection = options[:collection] || :reporting
		where = options[:where] || {'_id' => {'$gte' => start_date, '$lte' => end_date}}

		unless type
			result = []
			['visits','reads','avg'].each do |series|
				data = {}
				interval = session[collection].find({"_id" => {"$gte" => start_date, "$lt" => end_date}}).sort({"_id" => 1})
				interval.each do |doc|
					doc["_id"] = doc["_id"].strftime("%Y-%m-%d 00:00:00 -0300")
					data[doc["_id"]] = doc["value"][series]
				end
				result << {name: series, data: data}
			end
			return result
		else
			case type
			when 'langs','recommendation','algorithms', 'recommended', 'visits', 'reads', 'avg', 'visits_per_user'
				result = []
				categories = {}
				other = []
				interval = session[collection].find(where).sort({"_id" => 1})
				interval.each do |doc|
					if doc["value"][type] and doc["value"][type].kind_of?(Hash)
						doc["value"][type].each do |series, count|
							unless categories.has_key? series
								categories[series] = count 
							else
								categories[series] += count 
							end
						end
					end
				end

				if options.has_key? :sort and options[:sort]==-1
					categories = Hash[categories.sort_by{ |k,v| v*-1}]
				end

				if options.has_key? :show_top
					i=0
					categories.each do |series, count|
						i+=1
						other<<series if i>options[:show_top]
					end
				end

				# ['russian', 'arabic', 'greek', 'polish', 'french', 'spanish', 'hungarian', 'italian', 'norwegian', 'english', 'finnish', 'german', 'hebrew', 'korean', 'dutch', 'portuguese', 'swedish', 'farsi', 'pinyin'].each do |series|
				categories.each do |series,count|
					data = {}
					interval.each do |doc|
						begin
							doc["_id"] = doc["_id"].strftime("%Y-%m-%d 00:00:00 -0300")
						rescue 
						end
						
						begin
							data[doc["_id"]] = doc["value"][type] ? doc["value"][type][series] : 0
						rescue
							data[doc["_id"]] = 0
						end
					end
					series = 'n/a' if series=='null'
					result << {name: series, data: data} unless other.include?(series)
					if other.include?(series)
						has_other = false
						result.each do |row| 
							if row[:name]=='other' 
								row[:data].merge(data) do |key, oldval, newval|
									oldval = 0 unless oldval
									newval = 0 unless newval
									oldval + newval
								end
								has_other=true
							end
						end
						result << {name: 'other', data: data} unless has_other
					end
				end

			else
				result = {}
				session[collection].find({"_id" => {"$gte" => start_date, "$lt" => end_date}}).sort({"_id" => 1}).each do |doc|
					doc["_id"] = doc["_id"].strftime("%Y-%m-%d 00:00:00 -0300")
					result[doc["_id"]] = doc["value"][type]
				end
			end
			return result

		end
	end

  def self.update_standard_reporting(start_date=Time.now, end_date=Time.now)
    start_date = self.sod(start_date)
    end_date = self.eod(end_date)
    session = Mongoid.default_session

    Activity.collection.aggregate([
      {'$match' => { 'created_at' => {'$gte' => start_date, '$lt' => end_date}}},
      {'$project' => { '_id' => 0, 'session_id' => 1, 'activity' => 1, 'user_id' => 1, 'day' => {'$dayOfMonth' => '$created_at'}, 'month' => {'$month' => '$created_at'}, 'year' => {'$year' => '$created_at'}}},
      {'$project' => {
        'date' => {'$add' => ['$day', {'$multiply' => ['$month',100]}, {'$multiply' => ['$year',10000]}] },
        'activity' => '$activity',
        'session_id' => '$session_id',
        'user_id' => '$user_id'
        }
      },
      {'$group' => { _id: {date: '$date'}, sessions: {'$addToSet' => "$session_id"}, users: {'$addToSet' => "$user_id"}, activities: {'$push' => "$activity"}}},
      {'$project' => {sessions: {'$size' => "$sessions"}, users: {'$size' => "$users"}, activities: "$activities"}},
      {'$unwind' => "$activities"},
      {'$group' => {_id: {date:"$_id.date", activity: "$activities"}, sessions: {'$last' => "$sessions"}, users: {'$last' => "$users"}, count: {'$sum' => 1}}},
      {'$group' => {_id: "$_id.date", activities: { '$addToSet' => {activity: "$_id.activity", count: "$count"}}, sessions: {'$last' => "$sessions"}, users: {'$last' => "$users"}}}
    ], {'allowDiskUse' => true}).each do |day|

      # puts day
      session[:reporting_std].find(_id: day['_id']).upsert(day)

    end

	end

	def self.visits_per_user_per_week(date, tag)
		start_date = self.sod(date-7)
		end_date = self.eod(date-1)
		# puts "#{start_date.to_s} -> #{end_date.to_s}"
		obj={'_id' => date.strftime('%Y%m%d').to_i, 'tag' => tag, 'data' => {}}
		Activity.collection.aggregate([
			{'$match' => { 'created_at' => {'$gte' => start_date, '$lt' => end_date}, 'resource.tag' => {'$exists' => true}}},
			{'$project' => {'_id' => 0, 'external_user_id' => 1, 'session_id' => 1, 'resource.tag' => 1}},
			{'$group' => {'_id' => "$resource.tag.#{tag}", 'users' => { '$addToSet' => '$external_user_id'}, 'sessions' => {'$addToSet' =>'$session_id'}}},
			{'$project' => {'users' => {'$size' => "$users"}, 'sessions' => {'$size' => "$sessions"}}},
			{'$project' => {'visits_per_user' => {'$divide' => ["$sessions", "$users"]}}}
		], {'allowDiskUse' => true}).each do |agg|
			agg['_id']='N/A' if agg['_id']==''
			obj['data'][agg['_id']] = (agg['visits_per_user']*100).round/100.0 if agg['_id']
		end

		Mongoid.default_session[:reporting_visits_user_week].find(_id: obj['_id'], tag: tag).upsert(obj)

	end

	def self.activity_per_user_per_day(date, tag)
		start_date = self.sod(date)
		end_date = self.eod(date)
		obj={'_id' => date.strftime('%Y%m%d').to_i, 'tag' => tag, 'data' => {}}

		Activity.collection.aggregate([
				{'$match' => { 'created_at' => {'$gte' => start_date, '$lt' => end_date}, 'resource.tag' => {'$exists' => true}}},
				{'$project' => {'_id' => 0, 'activity' => 1, 'external_user_id' => 1, 'resource.tag' => 1}},
				{'$group' => {'_id' => "$resource.tag.#{tag}", 'users' => { '$addToSet' => '$external_user_id'}, 'activities' => {'$push' => '$activity'}}},
		 		{'$project' => {'users' => {'$size' => '$users'}, 'activities' => '$activities'}},
				{"$unwind" => "$activities"},
				{'$group' => {'_id' => {'tag' => '$_id', 'activity' => '$activities'}, 'users' => {'$min' => '$users'}, 'count' => {'$sum' => 1}}}
		], {'allowDiskUse' => true}).each do |agg|
			# puts agg
			agg['_id']['tag']='N/A' if agg['_id']['tag']==''
			if agg['_id']['tag']
				obj['data'][agg['_id']['tag']]||={'users'=>0,agg['_id']['activity']=>0}
				obj['data'][agg['_id']['tag']]['users']=agg['users']
				obj['data'][agg['_id']['tag']][agg['_id']['activity']]=agg['count']
			end
		end

		Mongoid.default_session[:reporting_activity_tag].find(_id: obj['_id'], tag: tag).upsert(obj)
	end

end







# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150416, "tag"=>"puab", "N/A"=>1.18, "A"=>1.05, "B"=>1.02})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150415, "tag"=>"puab", "N/A"=>1.19, "A"=>1.11, "B"=>1.01})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150414, "tag"=>"puab", "N/A"=>1.18, "A"=>1.03, "B"=>1.89})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150413, "tag"=>"puab", "N/A"=>1.15, "A"=>1.05, "B"=>1.69})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150412, "tag"=>"puab", "N/A"=>1.14, "A"=>1.05, "B"=>1.75})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150411, "tag"=>"puab", "N/A"=>1.14, "A"=>1.05, "B"=>1.75})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150410, "tag"=>"puab", "N/A"=>1.11, "A"=>1.05, "B"=>1.5})
# Mongoid.default_session[:reporting_visits_user_week].insert({"_id"=>20150409, "tag"=>"puab", "B"=>1.45, "A"=>1.05, "N/A"=>1.08})