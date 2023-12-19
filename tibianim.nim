import
  std/[asyncdispatch, os, httpclient, strutils, strformat, options],
  dimscord, dimscmd,
  ./scraper

let
  token = getEnv("TTOKEN")
  discord {.mainClient.} = newDiscordClient(token)
  cmd = discord.newHandler()

var client = newAsyncHttpClient()

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
  discard await cmd.handleInteraction(s, i)

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  echo("Ready as ", $r.user)
  await cmd.registerCommands()

cmd.addSlash("highscores") do (vocation: string, skill: string, amount: int):
  ## List highscores
  await i.deferResponse()

  let search = await client.searchHighscores(vocation, skill)

  var
    n: int
    highscores: string
    voc = capitalizeAscii(vocation)
    skillType = capitalizeAscii(skill)

  for highscore in search.all:
    if amount > n:
      if vocation == "all":
        highscores &= &"{highscore[0]}. {highscore[1]} {highscore[2]} {highscore[3]} {highscore[4]}\n"
      else:
        highscores &= &"{highscore[0]}. {highscore[1]} {highscore[3]} {highscore[4]}\n"
    else:
      break

    n += 1

  discard await i.followup(
    embeds = @[Embed(
      title: some fmt"Highscores - Top {amount} {voc} by {skillType}",
      description: some highscores,
      color: some 0x7789ec
    )]
  )

cmd.addSlash("online") do ():
  ## List online player information
  await i.deferResponse()

  let
    players = await client.onlinePlayers()
  
  var
    vocations: string
    topVocations: string

  for voc in players.vocs:
    vocations &= &"{voc[0]}: {voc[1]}\n"

  for voc in players.topVocs:
    topVocations &= &"{voc[0]}: {voc[1]} {voc[2]}\n"

  discard await i.followup(
    embeds = @[Embed(
      title: some "Online",
      color: some 0x7789ec,
      fields: some @[
        EmbedField(
          name: "Player Count",
          value: $players.count
        ),
        EmbedField(
          name: "Average Level",
          value: $players.avgLvl
        ),
        EmbedField(
          name: "Vocations",
          value: vocations
        ),
        EmbedField(
          name: "Top",
          value: topVocations
        )
      ]
    )]
  )

cmd.addSlash("character") do (player: string):
  ## Show player details
  await i.deferResponse()

  let character = await client.searchCharacter(player)

  var
    information: string
    deaths: string
    alts: string

  for info in character.info:
    information &= &"{info[0]}: {info[1]}\n"

  for death in character.deaths:
    deaths &= &"{death[0]} {death[1]}\n"

  for alt in character.alts:
    alts &= &"{alt[0]} {alt[1]} {alt[2]}\n"

  discard await i.followup(
    embeds = @[Embed(
      title: some "Character",
      color: some 0x7789ec,
      fields: some @[
        EmbedField(
          name: "Information",
          value: information
        ),
        EmbedField(
          name: "Deaths",
          value: deaths
        ),
        EmbedField(
          name: "Alts",
          value: alts
        )
      ]
    )]
  )

waitFor discord.startSession(
  gateway_intents = {
    giGuilds,
    giGuildMessages,
    giMessageContent
  }
)