//ChatGPT PROMPT:
// generate macOS command line tool use Swift and spm ArgumentParser to count total bytes across files specified as url arguments, supporting an -x:filespec to generate per file byte counts in the file filespec
//
struct Challenge :Codable,Hashable,Identifiable,Equatable {
  let id : String
  let question: String
  let topic: String
  let hint:String // a hint to show if the user needs help
  let answers: [String]
  let answer: String // which answer is correct
  let explanation: [String] // reasoning behind the correctAnswer
  let article: String // URL of article about the correct Answer
  let image:String // URL of image of correct Answer
}

// the Challenge structure (above) is also fed to chatgpt as part of the PROMPT

// build in xcode, go chase down executable in Derived Data then use this command to move executable
// sudo mv ./challenges /usr/local/bin/challenges

//sample data
// % challenges https://billdonner.com/fs/food.json https://billdonner.com/fs/oceans.json https://billdonner.com/fs/us_presidents.json https://billdonner.com/fs/vacation.json https://billdonner.com/fs/elvis_presley.json https://billdonner.com/fs/rock_and_roll.json https://billdonner.com/fs/rap_artists.json https://billdonner.com/fs/new_york_city.json https://billdonner.com/fs/world_heritage_sites.json https://billdonner.com/fs/the_himalayas.json

// challenges -f file:///Users/BillDonner/Desktop/foobar.json  https://billdonner.com/fs/food.json https://billdonner.com/fs/oceans.json https://billdonner.com/fs/us_presidents.json https://billdonner.com/fs/vacation.json https://billdonner.com/fs/elvis_presley.json https://billdonner.com/fs/rock_and_roll.json https://billdonner.com/fs/rap_artists.json https://billdonner.com/fs/new_york_city.json https://billdonner.com/fs/world_heritage_sites.json https://billdonner.com/fs/the_himalayas.json
 
//"Read, Validate, and de-duplicate remote json Challenge files  specified as url arguments, supporting an -f filespec to generate a GamePlay ready json file"

import Foundation
import ArgumentParser

var count : Int = 0
var bytesRead : Int = 0
var topicCounts: [String:Int] = [:]
var dupeCounts: [String:Int] = [:]



// MARK: - validate all files and segregate by topic

func analyze(_ urls:[String]) {
  // Iterate over the URLs and count the bytes read at each URL.
  for url in urls {
    // Get the data from the URL.
    guard let u = URL(string:url) else {
      print("Cant read url \(url)")
      continue
    }
    do {
      let data = try Data(contentsOf: u)
      bytesRead = data.count
      // Decode the data, which means converting data to Swift objects.
      do {
        let challenges = try JSONDecoder().decode([Challenge].self, from: data)
        count = challenges.count
        for challenge in challenges {
          let key = challenge.topic
          if let topic =  topicCounts [key] {
            topicCounts [key] = topic + 1
          } else {
            topicCounts [key ] = 1 // a new one
          }
          let qkey = challenge.question
          if let q =  dupeCounts [qkey] {
            dupeCounts [qkey] = q + 1
          } else {
            dupeCounts [qkey ] = 1 // a new one
          }
        }
        // At the end of each url, Print the bytes read and topics
        print("Read \(url) - \(bytesRead) bytes, \(count) challenges")
      }
      catch {
        print("Could not decode \(u)", error)
      }
    }
    catch {
      print("Can't read contents of \(url)" )
      continue
    }
  } // topics
  for (_, key_value) in topicCounts.enumerated() {
    let (key,value) = key_value
    print("Topic - \(key), \(value) challenges")
  }
  // duplicates
  for (_, key_value) in  dupeCounts.enumerated() {
    let (key,value) = key_value
    if value > 1 {
      print("Duplicate Question - \(key), \(value) dupes")
    }
  }
}



struct GameData : Codable, Hashable,Identifiable,Equatable {
  internal init(subject: String, challenges: [Challenge]) {
    self.subject = subject
    self.challenges = challenges //.shuffled()  //randomize
    self.id = UUID().uuidString
    self.generated = Date()
  }
  
  let id : String
  let subject: String
  let challenges: [Challenge]
  let generated: Date
}

// MARK: - write a local output file ready for loading into app

func writeJSONFile(_ urls:[String], outurl:URL)
{
  var allChallenges:[Challenge] = []
  var topicCount = 0
  var fileCount = 0
  for url in urls {
    // read all the urls again
    guard let u = URL(string:url) else {
      print("Cant read url \(url)")
      continue
    }
    do {
      fileCount += 1
      let data = try Data(contentsOf: u)
      let cha = try JSONDecoder().decode([Challenge].self, from: data)
      var removalIndices:[Int] = []
  
      for (index,challenge) in cha.enumerated(){
        // check if its a dupe
        let qkey = challenge.question
        if let q =  dupeCounts [qkey] {
          if q > 1 {
            dupeCounts [qkey] = q - 1
            removalIndices .append (index)
            //print("will remove at \(index) \(qkey)")
          } else {
            // last remaining entry  so dont remove it
            if q==0 { print("makes no sense")  }
            else {
             // print("keeping at \(index) \(qkey)")
            }
          }
        }
      }
      for (idx,chal) in cha.enumerated() {
        if !removalIndices.contains(idx) {
          allChallenges.append(chal)
        }
      }
    }
    catch {
      print("Could not read \(u)")
    }
    
  }
  
  //sort by topic
  allChallenges.sort(){ a,b in
    return a.topic < b.topic
  }
 //separate challenges by topic and make an array of GameDatas
  var gameDatum : [ GameData] = []
  var lastTopic: String? = nil
  var theseChallenges : [Challenge] = []
  for challenge in allChallenges {
   // print(challenge.topic,lastTopic)
    if let last = lastTopic  {
      if challenge.topic != last {
        gameDatum.append( GameData(subject:last,challenges: theseChallenges))
        theseChallenges = []
        topicCount += 1
      }
    }
      // append this challenge and set topic
      theseChallenges += [challenge]
      lastTopic = challenge.topic

  }
  if let last = lastTopic {
    topicCount += 1
    gameDatum.append( GameData(subject:last,challenges: theseChallenges)) //include remainders
  }
  
  // write Challenges as JSON to file
  let encoder = JSONEncoder()
  encoder.outputFormatting = .prettyPrinted
  do {
    let data = try encoder.encode(gameDatum)
    let json = String(data:data,encoding: .utf8)
    if let json  {
      try json.write(to: outurl, atomically: false, encoding: .utf8)
      print("Wrote \(json.count) bytes, \(allChallenges.count) challenges, \(topicCount) topics to \(outurl)")
    }
  }
  catch {
    print ("Can't write output \(error)")
  }
  
}

// MARK: - command line parsing with Argument Parser
struct Challenges: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read, Validate, and de-duplicate remote json Challenge files  specified as url arguments, supporting an -f filespec to generate a GamePlay ready json file",
        version: "0.1.1",
        subcommands: [],
        defaultSubcommand: nil,
        helpNames: [.long, .short]
    )

    @Option(name: .shortAndLong, help: "Specify the filespec for the GamePlay file")
    var filespec: String?

    @Argument(help: "List of URLs of files to process")
    var urls: [String]

    func run() throws {
      analyze(urls)


        // write outputs
      if let filespec = filespec , let furl = URL(string:filespec) {
          writeJSONFile(urls, outurl:furl)
        }
    }
}

Challenges.main()
exit(0)
