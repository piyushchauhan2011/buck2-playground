export type Language = "node" | "python" | "php" | "other";

export interface AffectedResult {
  build: string[];
  test: string[];
  quality: string[];
  byLanguage: {
    build: Record<Language, string[]>;
    test: Record<Language, string[]>;
    quality: Record<Language, string[]>;
  };
  needsNode: boolean;
  needsPython: boolean;
  needsPhp: boolean;
}

export interface SparseDirsResult {
  sparseDirs: string[];
}
