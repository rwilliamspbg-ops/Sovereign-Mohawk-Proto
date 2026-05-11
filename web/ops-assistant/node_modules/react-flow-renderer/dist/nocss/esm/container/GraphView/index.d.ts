import React from 'react';
import { NodeTypesWrapped, EdgeTypesWrapped, ConnectionLineType, KeyCode, ReactFlowProps, CoordinateExtent } from '../../types';
export interface GraphViewProps extends Omit<ReactFlowProps, 'onSelectionChange' | 'nodes' | 'edges' | 'nodeTypes' | 'edgeTypes'> {
    nodeTypes: NodeTypesWrapped;
    edgeTypes: EdgeTypesWrapped;
    selectionKeyCode: KeyCode | null;
    deleteKeyCode: KeyCode | null;
    multiSelectionKeyCode: KeyCode | null;
    connectionLineType: ConnectionLineType;
    onlyRenderVisibleElements: boolean;
    translateExtent: CoordinateExtent;
    minZoom: number;
    maxZoom: number;
    defaultZoom: number;
    defaultPosition: [number, number];
    defaultMarkerColor: string;
    selectNodesOnDrag: boolean;
    noDragClassName: string;
    noWheelClassName: string;
    noPanClassName: string;
}
declare const _default: React.MemoExoticComponent<{
    ({ nodeTypes, edgeTypes, onMove, onMoveStart, onMoveEnd, onInit, onNodeClick, onEdgeClick, onNodeDoubleClick, onEdgeDoubleClick, onNodeMouseEnter, onNodeMouseMove, onNodeMouseLeave, onNodeContextMenu, onSelectionContextMenu, connectionLineType, connectionLineStyle, connectionLineComponent, connectionLineContainerStyle, selectionKeyCode, multiSelectionKeyCode, zoomActivationKeyCode, deleteKeyCode, onlyRenderVisibleElements, elementsSelectable, selectNodesOnDrag, translateExtent, minZoom, maxZoom, defaultZoom, defaultPosition, preventScrolling, defaultMarkerColor, zoomOnScroll, zoomOnPinch, panOnScroll, panOnScrollSpeed, panOnScrollMode, zoomOnDoubleClick, panOnDrag, onPaneClick, onPaneScroll, onPaneContextMenu, onEdgeUpdate, onEdgeContextMenu, onEdgeMouseEnter, onEdgeMouseMove, onEdgeMouseLeave, edgeUpdaterRadius, onEdgeUpdateStart, onEdgeUpdateEnd, noDragClassName, noWheelClassName, noPanClassName, elevateEdgesOnSelect, id, }: GraphViewProps): JSX.Element;
    displayName: string;
}>;
export default _default;
