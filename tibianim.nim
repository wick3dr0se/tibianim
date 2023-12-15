import
  std/[asyncdispatch, os, httpclient, strutils, strformat, options],
  dimscord, dimscmd,
  ./scraper

let
  token = getEnv("TTOKEN")
  discord {.mainClient.} = newDiscordClient(token)
  cmd = discord.newHandler()

var
  client = newAsyncHttpClient()

proc interactionHandler*(s: Shard, i: Interaction) {.async.} =
  discard await cmd.handleInteraction(s, i)

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
  await interactionHandler(s, i)

proc slashRegistrar*() {.async.} = await cmd.registerCommands()

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  echo("Ready as ", $r.user, " in:")
  
  for g in r.guilds:
    let
      guild = await discord.api.getGuild(g.id)
      memb = await discord.api.getGuildMember(guild.id, r.user.id)
      perms = computePerms(guild, memb)

    echo("Guild: ", guild.name, "#", guild.id)
    echo("Permissions: ", perms.allowed)

    await slashRegistrar()

cmd.addSlash("online") do ():
  ## List online player information
  await i.deferResponse()

  let
    players = await client.onlinePlayers()
    vocations = join(players.voc, "\n")

  discard await i.followup(
    embeds = @[Embed(
      title: some "Online",
      color: some 0x7789ec,
      fields: some @[
        EmbedField(
          name: fmt"""
            > Player Count: `{players.count}`
            > Average Level: `{players.avgLvl}`
          """
        ),
        EmbedField(
          name: "Vocations",
          value: vocations
        )
      ]
    )]
  )

cmd.addSlash("house") do (town: string):
  ## List available houses
  await i.deferResponse()

  let
    houses = await client.searchHouses(town)
    allHouses = join(houses.all, "\n")

#House Count: `{houses.count}`
  discard await i.followup(
    embeds = @[Embed(
      title: some "Houses",
      description: some fmt"```{allHouses}```",
      color: some 0x7789ec
    )]
  )

cmd.addSlash("character") do (name: string):
  ## Show player details
  await i.deferResponse()

  let
    search = await client.searchPlayer(name)
    searchInfo = join(search.info, "\n")
    searchDeaths = join(search.deaths, "\n")

  var searchAlts: seq[string]

  for alt in search.alts:
    searchAlts.add(alt.all)

  discard await i.followup(
    embeds = @[Embed(
      title: some "Character",
      color: some 0x7789ec,
      fields: some @[
        EmbedField(
          name: "Information",
          value: searchInfo
        ),
        EmbedField(
          name: "Deaths",
          value: searchDeaths
        ),
        EmbedField(
          name: "Alts",
          value: join(searchAlts, "\n")
        )
      ]
    )]
  )

cmd.addSlash("highscores") do (vocation: string, skillType: string, amount: int):
  ## List highscores
  await i.deferResponse()

  let
    highscores = await client.searchHighscores(vocation, skillType)
    hs = (highscores.number, highscores.name, highscores.skill, highscores.exp)
    
  var h: string

  for i in 0..<hs[0].len:
    if i < amount:
      h &= $hs[0][i] & ". " & hs[1][i] & " " & $hs[2][i]

      if skillType == "level":
        h &= " " & $hs[3][i] & "\n"
      else:
        h &= "\n"

  discard await i.followup(
    embeds = @[Embed(
      title: some "Highscores - Top " & $amount,
      description: some h,
      color: some 0x7789ec
    )]
  )

cmd.addSlash("online-players") do ():
  ## List players online
  await i.deferResponse()

  let resp = await client.onlinePlayers()
  
  var players: string

  for r in resp.all:
    let chunk = r.replace(" ", " | ") & "\n"
    if players.len + chunk.len < 1999:
      discard await i.followup(players)
      players = chunk
    else:
      players &= chunk

  if players.len > 0:
    discard await i.followup(players)

waitFor discord.startSession(
  gateway_intents = {
    giGuilds,
    giGuildMessages,
    giMessageContent
  }
)