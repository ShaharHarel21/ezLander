export const ALLOWED_MODELS = ["gpt-4o", "gpt-4o-mini"] as const;

export type AllowedModel = (typeof ALLOWED_MODELS)[number];

export function isAllowedModel(model: string): model is AllowedModel {
  return (ALLOWED_MODELS as readonly string[]).includes(model);
}
