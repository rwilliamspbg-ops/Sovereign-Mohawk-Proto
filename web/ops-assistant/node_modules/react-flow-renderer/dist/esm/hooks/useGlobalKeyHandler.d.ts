import { KeyCode } from '../types';
interface HookParams {
    deleteKeyCode: KeyCode | null;
    multiSelectionKeyCode: KeyCode | null;
}
declare const _default: ({ deleteKeyCode, multiSelectionKeyCode }: HookParams) => void;
export default _default;
