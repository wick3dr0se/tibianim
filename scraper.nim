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
    topVoc*: seq[(string, string, int)]
  Houses = object
    number*: seq[int]
    name*: seq[string]
    desc*: seq[string]
    rent*: seq[int]
    size*: seq[int]
    state*: seq[string]
    all*: seq[string]
  Highscores = object
    number*: seq[int]
    name*: seq[string]
    voc*: seq[string]
    skill*: seq[int]
    exp*: seq[string]
    all*: seq[string]

const URI = "https://tibiantis.online"

proc onlinePlayers*(client: AsyncHttpClient): Future[Players] {.async.} =
  var
    players: Players
    i, rookCnt, knightCnt, paladinCnt, sorcererCnt, druidCnt: int
    eliteKnightCnt, royalPaladinCnt, masterSorcererCnt, elderDruidCnt: int
    lvlSum: int

  let
    content = await client.getContent(URI & "/?page=whoisonline")
    html = parseHtml(content)
    eles = html.findAll("table")[2]

  players.voc = newSeq[string](9)
  players.topVoc = newSeq[(string, string, int)](9)

  for e in eles:
    if i > 1:
      let (name, voc, lvl) = (e[1].innerText(), e[3].innertext(), parseInt(e[5].innertext()))

      case voc
      of "None":
        rookCnt += 1
        players.voc[0] = "Rook: " & $rookCnt

        if players.topVoc[0][2] < lvl:
          players.topVoc[0] = ("Rook: ", name, lvl)
      of "Knight":
        knightCnt += 1
        players.voc[1] = "Knights: " & $knightCnt

        if players.topVoc[1][2] < lvl:
          players.topVoc[1] = ("Knight: ", name, lvl)
      of "Elite Knight":
        eliteKnightCnt += 1
        players.voc[2] = "Elite Knights: " & $eliteKnightCnt

        if players.topVoc[2][2] < lvl:
          players.topVoc[2] = ("Elite Knight: ", name, lvl)
      of "Paladin":
        paladinCnt += 1
        players.voc[3] = "Paladins: " & $paladinCnt

        if players.topVoc[3][2] < lvl:
          players.topVoc[3] = ("Paladin: ", name, lvl)
      of "Royal Paladin":
        royalPaladinCnt += 1
        players.voc[4] = "Royal Paladins: " & $royalPaladinCnt

        if players.topVoc[4][2] < lvl:
          players.topVoc[4] = ("Royal Paladin: ", name, lvl)
      of "Sorcerer":
        sorcererCnt += 1
        players.voc[5] = "Sorcerers: " & $sorcererCnt

        if players.topVoc[5][2] < lvl:
          players.topVoc[5] = ("Sorcerer: ", name, lvl)
      of "Master Sorcerer":
        masterSorcererCnt += 1
        players.voc[6] = "Master Sorcerers: " & $masterSorcererCnt

        if players.topVoc[6][2] < lvl:
          players.topVoc[6] = ("Master Sorcerer: ", name, lvl)
      of "Druid":
        druidCnt += 1
        players.voc[7] = "Druids: " & $druidCnt

        if players.topVoc[7][2] < lvl:
          players.topVoc[7] = ("Druid: ", name, lvl)
      of "Elder Druid":
        elderDruidCnt += 1
        players.voc[8] = "Elder Druids: " & $elderDruidCnt

        if players.topVoc[8][2] < lvl:
          players.topVoc[8] = ("Elder Druid: ", name, lvl)
      else: discard

      players.name.add(name)
      players.lvl.add(lvl)
      players.all.add(name & " " & voc & " " & $lvl)

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
    eles = html.findAll("table")
    info = eles[2].toSeq()

  if eles.len() > 6:
    # deaths table exist
    let
      deaths = eles[3].toSeq()
    
    created = eles[4].toSeq()
    characters = eles[5].toSeq()

    for d in deaths:
      if n > 0:
        let death = replace(d.innerText(), d[0].innerText(), "") & " " & d[0].innerText()
        player.deaths.add(death)
      n += 1
  else:
    created = eles[3].toSeq()
    characters = eles[4].toSeq()

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

proc searchHouses*(client: AsyncHttpClient, town: string): Future[Houses] {.async.} =
  let
    content = await client.getContent(URI & "/?page=houses&town=" & town & "&gh=0&status=1&id=1&x=83&y=21")
    html = parseHtml(content)
    eles = html.findAll("td")
    houseInfo = eles[15..^2]

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

proc searchHighscores*(client: AsyncHttpClient, vocation: string, skill: string): Future[Highscores] {.async.} =
  var
    highscores: Highscores
    vocID: int
    cols: int
    offset: int

  case vocation
  of "druid": vocID = 1
  of "knight": vocID = 2
  of "paladin": vocID = 3
  of "sorcerer": vocID = 4

  if skill == "level":
    cols = 5
    offset = 11
  else:
    cols = 4
    offset = 10

  let
    content = await client.getContent(URI & "?page=highscores&stat=" & skill & "&voc=" & $vocID & "&c.x=41&c.y=24")
    html = parseHtml(content)
    eles = html.findAll("td")
    highscore = eles[offset..^2]

  for i in 0..<highscore.len div cols:
    let
      index = i * cols
      number = highscore[index].innerText().parseInt()
      name = highscore[index + 1].innerText()
      voc = highscore[index + 2].innerText()
      skillLvl = highscore[index + 3].innerText().parseInt()
    
    var exp: string

    if skill == "level":
      exp = highscore[index + 4].innerText()

    highscores.number.add(number)
    highscores.name.add(name)
    highscores.voc.add(voc)
    highscores.skill.add(skillLvl)
    highscores.exp.add(exp)

    highscores.all.add(
      $number & ". " & name & "\n" &
      "Vocation: " & voc & "\n" &
      "Skill Level: " & $skillLvl & "\n"
    )
  
  return highscores