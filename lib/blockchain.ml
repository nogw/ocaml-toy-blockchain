type timestamp = [%import: Unix.tm] [@@deriving yojson]

type block =
  | GenesisBlock of {
    index: int; 
    hash: string; 
    data: string; 
    timestamp: timestamp
  }
  | Block of { 
    index: int; 
    hash: string; 
    data: string; 
    timestamp: timestamp; 
    previous_block: block 
  }
  [@@deriving yojson]

let block index data timestamp previous_hash hash =
  Block {
    index; 
    hash; 
    data; 
    timestamp; 
    previous_block = previous_hash
  }

let index_of block =
  match block with 
  | GenesisBlock b -> b.index 
  | Block b -> b.index

let data_of block =
  match block with 
  | GenesisBlock b -> b.data 
  | Block b -> b.data

let timestamp_of block =
  match block with GenesisBlock b -> b.timestamp | Block b -> b.timestamp

let hash_of block =
  match block with GenesisBlock b -> b.hash | Block b -> b.hash

let previous_block_of block =
  match block with
  | GenesisBlock _ ->
      failwith "Error: tried to obtain previous hash of genesis block"
  | Block b -> b.previous_block

let hash_block index data ?(previous_hash = "") timestamp =
  [ string_of_int index; 
    previous_hash; 
    Unix.mktime timestamp |> fst |> string_of_float; 
    data ]
  |> String.concat "" |> Sha256.string |> Sha256.to_hex

let initial_block data =
  let timestamp = Unix.time () |> Unix.gmtime in
  GenesisBlock {
    index = 0; 
    data; 
    timestamp; 
    hash = hash_block 0 data timestamp
  }

let add_next_block data previous =
  let timestamp = Unix.time () |> Unix.gmtime
  and index = index_of previous + 1 in
  Block { 
    index; 
    hash= hash_block index data ~previous_hash:(hash_of previous) timestamp; 
    data; 
    timestamp; 
    previous_block= previous 
  }

let validate_new_block block =
  match block with
  | GenesisBlock _ -> true
  | Block b ->
      let previous_hash = hash_of (previous_block_of block) in
      let hash = hash_block b.index b.data ~previous_hash b.timestamp in
      let previous_index =
        match b.previous_block with
        | GenesisBlock pb -> pb.index
        | Block pb -> pb.index
      in
      b.index = previous_index + 1 && b.hash = hash

let validate_chain chain =
  let rec aux chain' res =
    match (chain', res) with
    | _, false -> false
    | GenesisBlock _, _ -> true
    | Block c, _ -> aux c.previous_block (validate_new_block chain')
  in
  aux chain true

let replace_chain new_chain chain =
  if index_of new_chain > index_of chain && validate_chain new_chain then
    new_chain
  else chain