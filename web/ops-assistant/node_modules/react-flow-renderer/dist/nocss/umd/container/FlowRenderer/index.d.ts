import React, { ReactNode } from 'react';
import { GraphViewProps } from '../GraphView';
export declare type FlowRendererProps = Omit<GraphViewProps, 'snapToGrid' | 'nodeTypes' | 'edgeTypes' | 'snapGrid' | 'connectionLineType' | 'connectionLineContainerStyle' | 'arrowHeadColor' | 'onlyRenderVisibleElements' | 'selectNodesOnDrag' | 'defaultMarkerColor'> & {
    children: ReactNode;
};
declare const _default: React.MemoExoticComponent<{
    ({ children, onPaneClick, onPaneContextMenu, onPaneScroll, deleteKeyCode, onMove, onMoveStart, onMoveEnd, selectionKeyCode, multiSelectionKeyCode, zoomActivationKeyCode, elementsSelectable, zoomOnScroll, zoomOnPinch, panOnScroll, panOnScrollSpeed, panOnScrollMode, zoomOnDoubleClick, panOnDrag, translateExtent, minZoom, maxZoom, defaultZoom, defaultPosition, preventScrolling, onSelectionContextMenu, noWheelClassName, noPanClassName, }: FlowRendererProps): JSX.Element;
    displayName: string;
}>;
export default _default;
