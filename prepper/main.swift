
 
//"Read, Validate, and de-duplicate remote json Challenge files  specified as url arguments, supporting an -f filespec to generate a GamePlay ready json file"

import Foundation
import ArgumentParser
import q20kshare


var count : Int = 0
var bytesRead : Int = 0
var topicCounts: [String:Int] = [:]
var dupeCounts: [String:Int] = [:]

// MARK: - validate all files and segregate by topic
func handle_challenges(challenges:[Challenge]) {

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
}
func printTopicsAndDuplicates () {
  for (_, key_value) in topicCounts.enumerated() {
    let (key,value) = key_value
    print("Topic - \(key), \(value) challenges")
  }
  // duplicates
  for (_, key_value) in  dupeCounts.enumerated() {
    let (key,value) = key_value
    if value > 1 {
      print("Duplicate Question - \(key), \(value-1) dupe")
    }
  }
}
fileprivate func fixupJSON(   data: Data, url: String)-> [Challenge] {
  // see if missing ] at end and fix it\
  do {
    return try Challenge.decodeArrayFrom(data: data)
  }
  catch {
    if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
      if !s.hasSuffix("]") {
        if let v = String(s+"]").data(using:.utf8) {
          do {
            return try Challenge.decodeArrayFrom(data: v)
          }
          catch {
            print("Can't read contents of \(url), error: \(error)" )
          }
        }
      }
    }
  }
  return []
}

func analyze(_ urls:[String]) {
  // Iterate over the URLs and count the bytes read at each URL.
  var data: Data
  var challenges:[Challenge] = []
  for url in urls {
    // Get the data from the URL.
    guard let u = URL(string:url) else {
      print("Cant parse url \(url)")
      continue
    }
    do {
       data = try Data(contentsOf: u)
    }
    catch {
      print("Can't read contents of \(url), error: \(error)" )
      continue
    }
    challenges = fixupJSON( data: data, url: url)

      // Decode the data, which means converting data to Swift objects.
    handle_challenges(challenges:challenges)
    print("Input \(url) - \(bytesRead) bytes, \(challenges.count) challenges")
  } // all urls
 printTopicsAndDuplicates()
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

fileprivate func cleanupChallenges(_ cha: [Challenge])->[Challenge] {
  var removalIndices:[Int] = []
  var challenges:[Challenge] = []
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
      challenges.append(chal)
    }
  }
  return challenges
}

func writeJSONFile(_ urls:[String], outurl:URL)
{
  var allChallenges:[Challenge] = []
  var topicCount = 0
  var fileCount = 0
  let start_time = Date()
  for url in urls {
    // read all the urls again
    guard let u = URL(string:url) else {
      print("Cant read url \(url)")
      continue
    }
    do {
      fileCount += 1
      let data = try Data(contentsOf: u)
      allChallenges =   fixupJSON(data:data,  url:u.absoluteString)
       
    }
    catch {
      print("Could not re-read \(u) error:\(error)")
      continue
      
    }
    print(">Prepper writing to \(url)")
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
        let elapsed = Date().timeIntervalSince(start_time)
        print(">Wrote \(json.count) bytes, \(allChallenges.count) challenges, \(topicCount) topics to \(outurl) in elapsed \(elapsed) secs")
      }
    }
    catch {
      print ("Can't write output \(error)")
    }
  }
}

// MARK: - command line parsing with Argument Parser
struct Prepper: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read, Validate, and de-duplicate remote json Challenge files  specified as url arguments, supporting an -f filespec to generate a GamePlay ready json file",
        version: "0.1.1",
        subcommands: [],
        defaultSubcommand: nil,
        helpNames: [.long, .short]
    )

    @Option(name: .shortAndLong, help: "Specify the filespec for the output GamePlay file")
    var gameFile: String?

    @Argument(help: "List of input URLs of files to process")
    var urls: [String]

    func run() throws {
      let start_time = Date()
      print(">Prepper Command Line: \(CommandLine.arguments)")
      print(">Prepper running at \(Date())")
      analyze(urls)
      if let filespec = gameFile , let furl = URL(string:filespec) {
          writeJSONFile(urls, outurl:furl)
        let elapsed = Date().timeIntervalSince(start_time)
        print(">Prepper finished in \(elapsed)secs")
        
        }

    }
}

Prepper.main()
exit(0)
