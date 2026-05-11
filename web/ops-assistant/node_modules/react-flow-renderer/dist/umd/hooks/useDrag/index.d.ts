import { RefObject } from 'react';
import { D3DragEvent, SubjectPosition } from 'd3-drag';
export declare type UseDragEvent = D3DragEvent<HTMLDivElement, null, SubjectPosition>;
export declare type UseDragData = {
    dx: number;
    dy: number;
};
declare type UseDragParams = {
    nodeRef: RefObject<Element>;
    disabled?: boolean;
    noDragClassName?: string;
    handleSelector?: string;
    nodeId?: string;
    isSelectable?: boolean;
    selectNodesOnDrag?: boolean;
};
declare function useDrag({ nodeRef, disabled, noDragClassName, handleSelector, nodeId, isSelectable, selectNodesOnDrag, }: UseDragParams): boolean;
export default useDrag;
