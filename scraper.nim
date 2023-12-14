import std/[asyncdispatch, httpclient, htmlparser, xmltree, strutils, sequtils, strformat]

type
  Alt = object
    all*: string
    name*: string
    lvl*: int
    world*: string
  Player = object
    info*: seq[string]
    deaths*: seq[string]
    alts*: seq[Alt]
  Players = object
    all*: seq[string]
    name*: seq[string] # may remove
    lvl*: seq[int] # may remove
    avgLvl*: float
    count*: int
    voc*: seq[string]
  Houses = object
    number*: seq[int]
    name*: seq[string]
    desc*: seq[string]
    rent*: seq[int]
    size*: seq[int]
    state*: seq[string]
    all*: seq[string]

const URI = "https://tibiantis.online"

proc onlinePlayers*(client: AsyncHttpClient): Future[Players] {.async.} =
  var
    players: Players
    i: int
    noneCount: int
    knightCount: int
    paladinCount: int
    sorcererCount: int
    druidCount: int
    lvlSum: int

  let
    content = await client.getContent(URI & "/?page=whoisonline")
    html = parseHtml(content)
    chars = html.findAll("table")[2]

  players.voc = newSeq[string](5)

  for c in chars:
    if i > 1:
      let (name, voc, lvl) = (c[1].innerText(), c[3].innertext(), parseInt(c[5].innertext()))

      case voc
      of "None":
        noneCount += 1
        players.voc[0] = "None: " & $noneCount
      of "Knight", "Elite Knight":
        knightCount += 1
        players.voc[1] = "Knights: " & $knightCount
      of "Paladin", "Royal Paladin":
        paladinCount += 1
        players.voc[2] = "Paladins: " & $paladinCount
      of "Sorcerer", "Master Sorcerer":
        sorcererCount += 1
        players.voc[3] = "Sorcerers: " & $sorcererCount
      of "Druid", "Elder Druid":
        druidCount += 1
        players.voc[4] = "Druids: " & $druidCount
      else: discard

      players.all.add(name & " " & voc & " " & $lvl)

      players.name.add(name)
      players.lvl.add(lvl)
      lvlSum += lvl
    i += 1

  players.count = i - 2
  players.avgLvl = lvlSum / players.count

  return players

proc searchPlayer*(client: AsyncHttpClient, name: string): Future[Player] {.async.} =
  var
    alt: Alt
    player: Player
    created: seq[XmlNode]
    characters: seq[XmlNode]
    n: int

  let
    content = await client.getContent(URI & "/?page=character&name=" & name)
    html = parseHtml(content)
    tables = html.findAll("table")
    info = tables[2].toSeq()

  if tables.len() > 6:
    # deaths table exist
    let
      deaths = tables[3].toSeq()
    
    created = tables[4].toSeq()
    characters = tables[5].toSeq()

    for d in deaths:
      if n > 0:
        let death = replace(d.innerText(), d[0].innerText(), "") & " " & d[0].innerText()
        player.deaths.add(death)
      n += 1
  else:
    created = tables[3].toSeq()
    characters = tables[4].toSeq()

  for i in info[1..^1]:
    let (key, val) = (i[0].innerText(), i[1].innerText())
    player.info.add(key & " " & capitalizeAscii(val))
  
  let accCreated = replace(created[1].innerText(), "Created:", "")
  player.info.add("Account Created: " & accCreated)

  for c in characters[2..^1]:
    let (altName, lvl, world) = (c[1].innerText(), parseInt(c[3].innerText()), c[5].innerText())
    
    # if names match ignore character
    if cmpIgnoreCase(altName, name) != 0:
      alt.name = altName
      alt.lvl = lvl
      alt.world = world

      alt.all = (altName & " " & $lvl & " " & world)
      player.alts.add(alt)
  
  return player

proc searchHouse*(client: AsyncHttpClient, town: string): Future[Houses] {.async.} =
  let
    content = await client.getContent(URI & "/?page=houses&town=" & town & "&gh=0&status=1&id=1&x=83&y=21")
    html = parseHtml(content)
    tables = html.findAll("td")
    houseInfo = tables[15..^2]

  var houses: Houses

  for i in 0..<houseInfo.len div 6:
    let
      index = i * 6
      number = houseInfo[index].innerText().parseInt()
      name = houseInfo[index + 1].innerText()
      desc = houseInfo[index + 2].innerText()
      rent = houseInfo[index + 3].innerText().parseInt()
      size = houseInfo[index + 4].innerText().parseInt()
      state = houseInfo[index + 5].innerText()
      
    houses.number.add(number)
    houses.name.add(name)
    houses.desc.add(desc)
    houses.rent.add(rent)
    houses.size.add(size)
    houses.state.add(state)

    houses.all.add(
      $number & ". " & name & "\n" &
      "Description: " & desc & "\n" &
      "Rent: " & $rent & "\n" &
      "Size: " & $size & "\n" &
      "State: " & state & "\n"
    )
  
  return houses