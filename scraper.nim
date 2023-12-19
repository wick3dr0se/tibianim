import std/[asyncdispatch, httpclient, htmlparser, xmltree, strutils, sequtils]

type
  Highscores = object
    all*: seq[(int, string, string, int, string)]
  Online = object
    count*: int
    avgLvl*: float
    vocs*: seq[(string, int)]
    topVocs*: seq[(string, string, int)]
    all*: seq[(string, string, int)]
  Character = object
    info*: seq[(string, string)]
    deaths*: seq[(string, string)]
    alts*: seq[(string, int, string)]
  Houses = object
    count*: int
    all*: seq[(int, string, string, int, int, string)]

const URI = "https://tibiantis.online"

# helpers
proc setTopVoc(online: var Online, id: int, voc: string, name: string, lvl: int) =
  if online.topVocs[id][2] < lvl: online.topVocs[id] = (voc, name, lvl)

# API
proc searchHighscores*(client: AsyncHttpClient, vocation: string, skill: string): Future[Highscores] {.async.} =
  var
    highscores: Highscores
    vocID: int
    cols: int
    offset: int
    exp: string

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
    let index = i * cols

    if skill == "level":
      exp = highscore[index + 4].innerText()

    highscores.all.add((
      highscore[index].innerText().parseInt(),
      highscore[index + 1].innerText(),
      highscore[index + 2].innerText(),
      highscore[index + 3].innerText().parseInt(),
      exp
    ))
  
  return highscores

proc onlinePlayers*(client: AsyncHttpClient): Future[Online] {.async.} =
  var
    online: Online
    i, rookCnt, knightCnt, paladinCnt, sorcererCnt, druidCnt: int
    eliteKnightCnt, royalPaladinCnt, masterSorcererCnt, elderDruidCnt: int
    lvlSum: int

  let
    content = await client.getContent(URI & "/?page=whoisonline")
    html = parseHtml(content)
    eles = html.findAll("table")[2]

  online.topVocs = newSeq[(string, string, int)](9)

  for e in eles:
    if i > 1:
      let (name, voc, lvl) = (e[1].innerText(), e[3].innertext(), parseInt(e[5].innertext()))

      case voc
      of "None":
        rookCnt += 1
        online.setTopVoc(0, "Rook", name, lvl)
      of "Knight":
        knightCnt += 1
        online.setTopVoc(1, voc, name, lvl)
      of "Elite Knight":
        eliteKnightCnt += 1
        online.setTopVoc(2, voc, name, lvl)
      of "Paladin":
        paladinCnt += 1
        online.setTopVoc(3, voc, name, lvl)
      of "Royal Paladin":
        royalPaladinCnt += 1
        online.setTopVoc(4, voc, name, lvl)
      of "Sorcerer":
        sorcererCnt += 1
        online.setTopVoc(5, voc, name, lvl)
      of "Master Sorcerer":
        masterSorcererCnt += 1
        online.setTopVoc(6, voc, name, lvl)
      of "Druid":
        druidCnt += 1
        online.setTopVoc(7, voc, name, lvl)
      of "Elder Druid":
        elderDruidCnt += 1
        online.setTopVoc(8, voc, name, lvl)
      else: discard

      lvlSum += lvl
      online.all.add((name, voc, lvl))
    i += 1

  online.count = i - 2
  online.avgLvl = lvlSum / online.count

  online.vocs = @[
    ("Rook", rookCnt),
    ("Knights", knightCnt),
    ("Elite Knights", eliteKnightCnt),
    ("Paladins", paladinCnt),
    ("Royal Paladins", royalPaladinCnt),
    ("Sorcerers", sorcererCnt),
    ("Master Sorcerers", masterSorcererCnt),
    ("Druids", druidCnt),
    ("Elder Druids", elderDruidCnt)
  ]

  return online

proc searchCharacter*(client: AsyncHttpClient, player: string): Future[Character] {.async.} =
  var
    character: Character
    created: seq[XmlNode]
    characters: seq[XmlNode]
    n: int

  let
    content = await client.getContent(URI & "/?page=character&name=" & player)
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
        let death = replace(d.innerText(), d[0].innerText(), "")
        character.deaths.add((death, d[0].innerText()))
      n += 1
  else:
    created = eles[3].toSeq()
    characters = eles[4].toSeq()

  for i in info[1..^1]:
    let (key, val) = (i[0].innerText(), capitalizeAscii(i[1].innerText))
    character.info.add((key[0..^2], val))
  
  let accCre = replace(created[1].innerText(), "Created:", "")
  character.info.add(("Account Created", accCre))

  for c in characters[2..^1]:
    let (name, lvl, world) = (c[1].innerText(), parseInt(c[3].innerText()), c[5].innerText())
    
    # if alt name matches player ignore character
    if cmpIgnoreCase(name, player) != 0:
      character.alts.add((name, lvl, world))
  
  return character

proc searchHouses*(client: AsyncHttpClient, town: string): Future[Houses] {.async.} =
  let
    content = await client.getContent(URI & "/?page=houses&town=" & town & "&gh=0&status=1&id=1&x=83&y=21")
    html = parseHtml(content)
    eles = html.findAll("td")
    houseInfo = eles[15..^2]

  var houses: Houses

  for i in 0..<houseInfo.len div 6:
    let index = i * 6
    
    houses.all.add((
      houseInfo[index].innerText().parseInt(),
      houseInfo[index + 1].innerText(),
      houseInfo[index + 2].innerText(),
      houseInfo[index + 3].innerText().parseInt(),
      houseInfo[index + 4].innerText().parseInt(),
      houseInfo[index + 5].innerText()
    ))

    houses.count += 1

  return houses