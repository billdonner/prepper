//ChatGPT PROMPT:
// generate macOS command line tool use Swift and spm ArgumentParser to count total bytes across files specified as url arguments, supporting an -x:filespec to generate per file byte counts in the file filespec
// build in xcode, go chase down executable in Derived Data then use this command to move executable
// sudo mv ./challenges /usr/local/bin/challenges

//sample data
// % challenges https://billdonner.com/fs/food.json https://billdonner.com/fs/oceans.json https://billdonner.com/fs/us_presidents.json https://billdonner.com/fs/vacation.json https://billdonner.com/fs/elvis_presley.json https://billdonner.com/fs/rock_and_roll.json https://billdonner.com/fs/rap_artists.json https://billdonner.com/fs/new_york_city.json https://billdonner.com/fs/world_heritage_sites.json https://billdonner.com/fs/the_himalayas.json
 
//"Read, Validate, and de-duplicate remote json Challenge files  specified as url arguments, supporting an -f filespec to generate a GamePlay ready json file"

import Foundation
import ArgumentParser

var count : Int = 0
var bytesRead : Int = 0
var topicCounts: [String:Int] = [:]
var dupeCounts: [String:Int] = [:]

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
func writeJSONFile(_ urls:[String], outurl:URL)
{
  var allChallenges:[Challenge] = []
  //  guard let outurl = URL(string :tourl) else {
  //    print ("cant write to \(tourl)")
  //    return
  //  }
  for url in urls {
    // read all the urls again
    guard let u = URL(string:url) else {
      print("Cant read url \(url)")
      continue
    }
    do {
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
  // write Challenges as JSON to file
  let encoder = JSONEncoder()
  encoder.outputFormatting = .prettyPrinted
  do {
    let data = try encoder.encode(allChallenges)
    let json = String(data:data,encoding: .utf8)
    if let json  {
      try json.write(to: outurl, atomically: false, encoding: .utf8)
      print("Wrote \(json.count) bytes, \(allChallenges.count) challenges to \(outurl)")
    }
  }
  catch {
    print ("Can't write output \(error)")
  }
  
}
struct Challenges: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read, Validate, and de-duplicate remote json Challenge files  specified as url arguments, supporting an -f filespec to generate a GamePlay ready json file",
        version: "0.1.0",
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
