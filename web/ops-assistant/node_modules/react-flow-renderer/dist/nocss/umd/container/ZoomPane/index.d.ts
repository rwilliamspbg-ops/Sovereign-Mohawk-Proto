/// <reference types="react" />
import { FlowRendererProps } from '../FlowRenderer';
declare type ZoomPaneProps = Omit<FlowRendererProps, 'deleteKeyCode' | 'selectionKeyCode' | 'multiSelectionKeyCode' | 'noDragClassName'> & {
    selectionKeyPressed: boolean;
};
declare const ZoomPane: ({ onMove, onMoveStart, onMoveEnd, zoomOnScroll, zoomOnPinch, panOnScroll, panOnScrollSpeed, panOnScrollMode, zoomOnDoubleClick, selectionKeyPressed, elementsSelectable, panOnDrag, translateExtent, minZoom, maxZoom, defaultZoom, defaultPosition, zoomActivationKeyCode, preventScrolling, children, noWheelClassName, noPanClassName, }: ZoomPaneProps) => JSX.Element;
export default ZoomPane;
