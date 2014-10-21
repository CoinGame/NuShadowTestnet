Before do
  @blocks = {}
  @addresses = {}
  @nodes = {}
  @tx = {}
  @raw_tx = {}
  @raw_tx_complete = {}
  @pubkeys = {}
  @unit = {}
end

Given(/^a network with nodes? (.+)(?: able to mint)?$/) do |node_names|
  node_names = node_names.scan(/"(.*?)"/).map(&:first)
  available_nodes = %w( a b c d e )
  raise "More than #{available_nodes.size} nodes not supported" if node_names.size > available_nodes.size
  @nodes = {}

  node_names.each_with_index do |name, i|
    options = {
      image: "nunet/#{available_nodes[i]}",
      links: @nodes.values.map(&:name),
      args: {
        debug: true,
        timetravel: 5*24*3600,
      },
    }
    node = CoinContainer.new(options)
    @nodes[name] = node
    node.wait_for_boot
  end

  wait_for(10) do
    @nodes.values.all? do |node|
      count = node.connection_count
      count == @nodes.size - 1
    end
  end
  wait_for do
    @nodes.values.map do |node|
      count = node.block_count
      count
    end.uniq.size == 1
  end
end

Given(/^a node "(.*?)" with an empty wallet$/) do |arg1|
  name = arg1
  options = {
    image: "nunet/a",
    links: @nodes.values.map(&:name),
    args: {
      debug: true,
      timetravel: 5*24*3600,
    },
    remove_wallet_before_startup: true,
  }
  node = CoinContainer.new(options)
  @nodes[name] = node
  node.wait_for_boot
end

Given(/^a node "(.*?)" with an empty wallet and with avatar mode disabled$/) do |arg1|
  name = arg1
  options = {
    image: "nunet/a",
    links: @nodes.values.map(&:name),
    args: {
      debug: true,
      timetravel: 5*24*3600,
      avatar: false,
    },
    remove_wallet_before_startup: true,
  }
  node = CoinContainer.new(options)
  @nodes[name] = node
  node.wait_for_boot
end

After do
  if @nodes
    require 'thread'
    @nodes.values.reverse.map do |node|
      Thread.new do
        node.shutdown
        #node.wait_for_shutdown
        #begin
        #  node.container.delete(force: true)
        #rescue
        #end
      end
    end.each(&:join)
  end
end

When(/^node "(.*?)" finds a block "([^"]*?)"$/) do |node, block|
  @blocks[block] = @nodes[node].generate_stake
end

When(/^node "(.*?)" finds a block$/) do |node|
  @nodes[node].generate_stake
end

When(/^node "(.*?)" finds (\d+) blocks$/) do |arg1, arg2|
  arg2.to_i.times do
    @nodes[arg1].generate_stake
  end
end

Then(/^all nodes should be at block "(.*?)"$/) do |block|
  begin
    wait_for do
      main = @nodes.values.map(&:top_hash)
      main.all? { |hash| hash == @blocks[block] }
    end
  rescue
    raise "Not at block #{block}: #{@nodes.values.map(&:top_hash).map { |hash| @blocks.key(hash) }.inspect}"
  end
end

Given(/^all nodes reach the same height$/) do
  wait_for do
    expect(@nodes.values.map(&:block_count).uniq.size).to eq(1)
  end
end

When(/^node "(.*?)" votes an amount of "(.*?)" for custodian "(.*?)"$/) do |arg1, arg2, arg3|
  node = @nodes[arg1]
  vote = node.rpc("getvote")
  vote["custodians"] << {
    "amount" => parse_number(arg2),
    "address" => @addresses[arg3],
  }
  node.rpc("setvote", vote)
end

When(/^node "(.*?)" votes a park rate of "(.*?)" NuBits per Nubit parked during (\d+) blocks$/) do |arg1, arg2, arg3|
  node = @nodes[arg1]
  vote = node.rpc("getvote")
  vote["parkrates"] = [
    {
      "unit" => "B",
      "rates" => [
        {
          "blocks" => arg3.to_i,
          "rate" => parse_number(arg2),
        },
      ],
    },
  ]
  node.rpc("setvote", vote)
  expect(node.rpc("getvote")["parkrates"]).to eq(vote["parkrates"])
end

When(/^node "(.*?)" finds blocks until custodian "(.*?)" is elected$/) do |arg1, arg2|
  node = @nodes[arg1]
  loop do
    block = node.generate_stake
    info = node.rpc("getblock", block)
    if elected_custodians = info["electedcustodians"]
      if elected_custodians.has_key?(@addresses[arg2])
        break
      end
    end
  end
end

When(/^node "(.*?)" finds blocks until the NuBit park rate for (\d+) blocks is "(.*?)"$/) do |arg1, arg2, arg3|
  node = @nodes[arg1]
  wait_for do
    block = node.generate_stake
    info = node.rpc("getblock", block)
    park_rates = info["parkrates"].detect { |r| r["unit"] == "B" }
    expect(park_rates).not_to be_nil
    rates = park_rates["rates"]
    rate = rates.detect { |r| r["blocks"] == arg2.to_i }
    expect(rate).not_to be_nil
    expect(rate["rate"]).to eq(parse_number(arg3))
  end
end

When(/^node "(.*?)" finds blocks until custodian "(.*?)" is elected in transaction "(.*?)"$/) do |arg1, arg2, arg3|
  node = @nodes[arg1]
  address = @addresses[arg2]
  loop do
    block = node.generate_stake
    info = node.rpc("getblock", block)
    if elected_custodians = info["electedcustodians"]
      if elected_custodians.has_key?(address)
        info["tx"].each do |txid|
          tx = node.rpc("getrawtransaction", txid, 1)
          tx["vout"].each do |out|
            if out["scriptPubKey"]["addresses"] == [address]
              @tx[arg3] = txid
              break
            end
          end
        end
        raise "Custodian grant transaction not found" if @tx[arg3].nil?
        break
      end
    end
  end
end

When(/^node "(.*?)" sends "(.*?)" to "([^"]*?)" in transaction "(.*?)"$/) do |arg1, arg2, arg3, arg4|
  @tx[arg4] = @nodes[arg1].rpc "sendtoaddress", @addresses[arg3], parse_number(arg2)
end

When(/^node "(.*?)" sends "(.*?)" to "([^"]*?)"$/) do |arg1, arg2, arg3|
  @nodes[arg1].rpc "sendtoaddress", @addresses[arg3], parse_number(arg2)
end

When(/^node "(.*?)" sends "(.*?)" (NuBits|NBT|NuShares|NSR) to "(.*?)"$/) do |arg1, arg2, unit_name, arg3|
  @nodes[arg1].unit_rpc unit(unit_name), "sendtoaddress", @addresses[arg3], parse_number(arg2)
end

When(/^node "(.*?)" finds a block received by all other nodes$/) do |arg1|
  node = @nodes[arg1]
  block = node.generate_stake
  wait_for do
    main = @nodes.values.map(&:top_hash)
    main.all? { |hash| hash == block }
  end
end

Then(/^node "(.*?)" (?:should reach|reaches) a balance of "([^"]*?)"( NuBits| NuShares|)$/) do |arg1, arg2, unit_name|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  wait_for do
    expect(node.unit_rpc(unit(unit_name), "getbalance")).to eq(amount)
  end
end

Then(/^node "(.*?)" should have a balance of "([^"]*?)"( NuBits|)$/) do |arg1, arg2, unit_name|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  expect(node.unit_rpc(unit(unit_name), "getbalance")).to eq(amount)
end

Then(/^node "(.*?)" should reach an unconfirmed balance of "([^"]*?)"( NuBits|)$/) do |arg1, arg2, unit_name|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  wait_for do
    expect(node.unit_rpc(unit(unit_name), "getbalance", "*", 0)).to eq(amount)
  end
end

Then(/^node "(.*?)" should have an unconfirmed balance of "([^"]*?)"( NuBits|)$/) do |arg1, arg2, unit_name|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  expect(node.unit_rpc(unit(unit_name), "getbalance", "*", 0)).to eq(amount)
end

Then(/^node "(.*?)" should reach a balance of "([^"]*?)"( NuBits|) on account "([^"]*?)"$/) do |arg1, arg2, unit_name, account|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  wait_for do
    expect(node.unit_rpc(unit(unit_name), "getbalance", account)).to eq(amount)
  end
end

Given(/^node "(.*?)" generates a (\w+) address "(.*?)"$/) do |arg1, unit_name, arg2|
  unit_name = "NuShares" if unit_name == "new"
  @addresses[arg2] = @nodes[arg1].unit_rpc(unit(unit_name), "getnewaddress")
  @unit[@addresses[arg2]] = unit(unit_name)
end

When(/^node "(.*?)" sends "(.*?)" shares to "(.*?)" through transaction "(.*?)"$/) do |arg1, arg2, arg3, arg4|
  @tx[arg4] = @nodes[arg1].rpc "sendtoaddress", @addresses[arg3], arg2.to_f
end

Then(/^transaction "(.*?)" on node "(.*?)" should have (\d+) confirmations?$/) do |arg1, arg2, arg3|
  wait_for do
    expect(@nodes[arg2].rpc("gettransaction", @tx[arg1])["confirmations"]).to eq(arg3.to_i)
  end
end

Then(/^all nodes should (?:have|reach) (\d+) transactions? in memory pool$/) do |arg1|
  wait_for do
    expect(@nodes.values.map { |node| node.rpc("getmininginfo")["pooledtx"] }).to eq(@nodes.map { arg1.to_i })
  end
end

Then(/^the NuBit balance of node "(.*?)" should reach "(.*?)"$/) do |arg1, arg2|
  wait_for do
    expect(@nodes[arg1].unit_rpc('B', 'getbalance')).to eq(parse_number(arg2))
  end
end

When(/^some time pass$/) do
  @nodes.values.each do |node|
    node.rpc "timetravel", 5
  end
end

When(/^node "(.*?)" finds enough blocks to mature a Proof of Stake block$/) do |arg1|
  node = @nodes[arg1]
  3.times do
    node.generate_stake
  end
end

When(/^node "(.*?)" parks "(.*?)" NuBits (?:for|during) (\d+) blocks$/) do |arg1, arg2, arg3|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  blocks = arg3.to_i

  node.unit_rpc('B', 'park', amount, blocks)
end

When(/^node "(.*?)" unparks$/) do |arg1|
  node = @nodes[arg1]
  node.unit_rpc('B', 'unpark')
end

Then(/^"(.*?)" should have "(.*?)" NuBits parked$/) do |arg1, arg2|
  node = @nodes[arg1]
  amount = parse_number(arg2)
  info = node.unit_rpc("B", "getinfo")
  expect(info["parked"]).to eq(amount)
end

When(/^the nodes travel to the Nu protocol v(\d+) switch time$/) do |arg1|
  switch_time = Time.at(1414195200)
  @nodes.values.each do |node|
    time = Time.parse(node.info["time"])
    node.rpc("timetravel", (switch_time - time).round)
  end
end

Then(/^node "(.*?)" should have (\d+) (\w+) transactions?$/) do |arg1, arg2, unit_name|
  @listtransactions = @nodes[arg1].unit_rpc(unit(unit_name), "listtransactions")
  begin
    expect(@listtransactions.size).to eq(arg2.to_i)
  rescue RSpec::Expectations::ExpectationNotMetError
    require 'pp'
    pp @listtransactions
    raise
  end
end

Then(/^the (\d+)\S+ transaction should be a send of "(.*?)" to "(.*?)"$/) do |arg1, arg2, arg3|
  tx = @listtransactions[arg1.to_i - 1]
  expect(tx["category"]).to eq("send")
  expect(tx["amount"]).to eq(-parse_number(arg2))
  expect(tx["address"]).to eq(@addresses[arg3])
end

Then(/^the (\d+)\S+ transaction should be a receive of "(.*?)" to "(.*?)"$/) do |arg1, arg2, arg3|
  tx = @listtransactions[arg1.to_i - 1]
  expect(tx["category"]).to eq("receive")
  expect(tx["amount"]).to eq(parse_number(arg2))
  expect(tx["address"]).to eq(@addresses[arg3])
end
