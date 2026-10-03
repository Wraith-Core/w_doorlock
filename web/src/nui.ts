/* The page's calls into Lua - or into the browser stand-in in development (dev/mock.ts) */

declare function GetParentResourceName(): string;

const resource = (): string => {
  try {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'w_doorlock';
  } catch {
    return 'w_doorlock';
  }
};

interface MockHost { callback?: (name: string, data: unknown) => unknown }

export async function post<T = unknown>(name: string, data: unknown = {}): Promise<T | null> {
  const mock = (window as unknown as { __dlMock?: MockHost }).__dlMock;
  if (mock?.callback) {
    try { return (await mock.callback(name, data)) as T; } catch { return null; }
  }
  try {
    const res = await fetch(`https://${resource()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

/** The game's own menu sounds (Config.Sounds), played by Lua */
export type Cue = 'navUp' | 'navDown' | 'select' | 'back' | 'locked' | 'toggleOn' | 'toggleOff';
export const cue = (name: Cue) => { void post('dl:sound', { name }); };
