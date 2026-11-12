export type Lang = 'ar' | 'en';

/** locales/{ar,en}.json exactly as Lua sends them (w_lib's flattened dictionary) */
export type Strings = Record<string, string>;

export interface Vec3 { x: number; y: number; z: number }

/** A round of the lock pick: a preset, or its own target size (degrees) and speed */
export type Difficulty = 'easy' | 'medium' | 'hard' | { areaSize: number; speedMultiplier: number };

/** A round as the server draws it: the zone and the speed are the server's, and it alone judges a press */
export interface PickRound { from: number; areaSize: number; speedMultiplier: number }

export interface DoorItem { name: string; metadata?: string; remove?: boolean }

export interface DoorLeaf { coords: Vec3; heading?: number; model?: number; hash?: number }

/** A door as the server keeps it - ox_doorlock's row, plus the region it stands in */
export interface Door {
  id: number;
  name: string;
  zone?: string;
  coords: Vec3;
  heading?: number;
  model?: number;
  hash?: number;
  doors?: DoorLeaf[];
  state: number;
  passcode?: string;
  autolock?: number;
  maxDistance?: number;
  doorRate?: number;
  lockSound?: string;
  unlockSound?: string;
  auto?: boolean;
  lockpick?: boolean;
  hideUi?: boolean;
  holdOpen?: boolean;
  characters?: (string | number)[];
  groups?: Record<string, number> | string | string[];
  items?: (DoorItem | string)[];
  lockpickDifficulty?: Difficulty[];
  /** 2.2.0: the w_store store whose owner and staff use the door */
  store?: number;
  /** the notebook board (2026-11-12, set by Lua on the way to the page): the name in words, the place and distance */
  label?: string;
  where?: string;
  meters?: number;
}

/** The names the board shows instead of keys (w_doorlock:admin:names) */
export interface GroupName { name: string; kind: 'job' | 'gang'; en: string; ar: string; grades: { grade: number; en: string; ar: string }[] }
export interface ItemName { name: string; label: string }
export interface Names { groups: GroupName[]; items: ItemName[] }

/** A new door whose leaves were taken in the world (J on a door) */
export interface Fresh { double: boolean; where?: string; /** a new door with nothing taken yet (J «باب جديد من اللوحة») */ blank?: boolean }

/** 2.2.0: a w_store store the board may link a door to (its cashier's place, for the nearest first) */
export interface StoreOption { id: number; name: string; owner?: string; at?: Vec3 }

export type RoundKind = 'easy' | 'medium' | 'hard' | 'custom';
export interface RoundForm { kind: RoundKind; areaSize: string; speedMultiplier: string }

/** What the editor edits: text while it is typed, turned into numbers on the way out */
export interface Form {
  name: string;
  passcode: string;
  autolock: string;
  maxDistance: string;
  doorRate: string;
  lockSound: string;
  unlockSound: string;
  state: boolean;
  double: boolean;
  auto: boolean;
  lockpick: boolean;
  hideUi: boolean;
  holdOpen: boolean;
  characters: string[];
  groups: { name: string; grade: string }[];
  items: { name: string; metadata: string; remove: boolean }[];
  rounds: RoundForm[];
  /** the linked store's id as text, '' = none */
  store: string;
}

export type Tab = 'general' | 'characters' | 'store' | 'groups' | 'items' | 'lockpick';

export interface BoardOpen {
  n: number;
  doors: Door[];
  sounds: string[];
  defaultSound?: string;
  stores: StoreOption[];
  focus?: number;
  names: Names;
  /** w_lib has the world mode (TAB) */
  world: boolean;
  fresh?: Fresh;
}

export interface BoardResume {
  n: number;
  saved?: Door;
}
