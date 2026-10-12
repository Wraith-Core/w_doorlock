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
}

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
}

export type Tab = 'general' | 'characters' | 'groups' | 'items' | 'lockpick';

export interface BoardOpen {
  n: number;
  doors: Door[];
  sounds: string[];
  defaultSound?: string;
  focus?: number;
}

export interface BoardResume {
  n: number;
  saved?: Door;
}
