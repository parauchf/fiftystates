#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), '..', 'rbutils', 'legislation')

module Idaho  
  include Scrapable
   
   def self.parse_sponsors(sponsor_text)
      sponsors=[]
      sponsor_text=$1 if sponsor_text =~ /by (.*)/
      if (sponsor_text =~ /\bCOMMITTEE\b/)
         sponsors=[sponsor_text];
      else
         sponsors=sponsor_text.split(/\bAND\b|,/).
            each{|name| name.strip!}.
            select{|name| "" != name}
      end
      return sponsors
   end
   
   def self.parse_actions(action_docs)
      actions=[]
      action_docs.select{|tr| (tr/'td[2]').inner_text =~ %r!\d{2}/\d{2}!}.each do |tr|
         date = (tr/'td[2]').inner_text.strip + "/#{$year}"
         event_text = (tr/'td[3]').inner_text
         actions.push({ :action_date=>date,
                        :action_text=>event_text})
      end
      return actions
   end
   
   def self.parse_versions(bill_doc)
      versions=[]
      (bill_doc/'a').select{|a| a['id'] =~ /^(H|S)\d{4}(E\d)?$/}.each do |a|
         version=a.inner_text
         text_link="http://www.legislature.idaho.gov/legislation/#{$year}/"+a['href']
         versions.push({ :version_name=>version,
                         :version_url=>text_link})
      end
      return versions
   end
   
   def self.get_bill(common_hash)
      puts "Fetching #{common_hash[:bill_id]}\n"
      open(common_hash[:remote_url]) do |bill_page|
         bill_doc = Hpricot.parse(bill_page.read)
      
         #get bill versoins
         versions=parse_versions(bill_doc)
         versions.each do |version|
             add_bill_version(common_hash.merge(version))
         end
         
         #get and parse the sponsor(s)
         csspath='html>body>table>tr>td[2]>table[1]>tr>td[3]'
         sponsors=parse_sponsors((bill_doc/csspath).inner_html)
         sponsors.each do |sponsor|
            add_sponsorship(common_hash.merge({ 
               :sponsor_name=>sponsor,
               :sponsor_type=>'primary'}))
         end
         
         #get the action history and parse it
         csspath='html>body>table>tr>td[2]>table[3]>tr'
         actions=parse_actions(bill_doc/csspath)
         actions.each do |action|
            add_action(common_hash.merge(action))
         end
      end
   end
   
   def self.state
      'id'
   end
   
   #main script
   def self.scrape_bills(chamber, year)
      $year=year
      open( "http://www.legislature.idaho.gov/"+
            "legislation/#{$year}/minidata.htm") do |page|
         doc = Hpricot.parse(page.read)
         
         
  
         #get all the tr's that have the right kind of id
         (doc/'tr').select{|tr| tr['id'] =~ /bill(H|S)\d{4}/}.each do |tr|
            bill_chamber = $2 == 'S' ? 'upper' : 'lower'
            bill_id=$1 if ((tr/'td')[0].inner_text)=~/((H|S)\d{4})/
            remote_url='http://www.legislature.idaho.gov'+
                  (tr/'td/a').first['href'].to_s
            bill_name=(tr/'td')[1].inner_text.strip
            common_hash={
               :bill_id=>bill_id,
               :bill_state=>'id',
               :bill_session=>$year,
               :bill_chamber=>bill_chamber,
               :remote_url=>remote_url
            }
            
            #add the main bill hash
            add_bill(common_hash.merge({:bill_name=>bill_name}))
         
            #scrape the individual bill pages
            get_bill(common_hash)
         end
      end
   end
end
Idaho.run
   
