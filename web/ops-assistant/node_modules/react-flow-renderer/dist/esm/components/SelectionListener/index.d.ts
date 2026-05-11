/// <reference types="react" />
import { OnSelectionChangeFunc } from '../../types';
interface SelectionListenerProps {
    onSelectionChange: OnSelectionChangeFunc;
}
declare function SelectionListener({ onSelectionChange }: SelectionListenerProps): null;
declare const _default: import("react").MemoExoticComponent<typeof SelectionListener>;
export default _default;
