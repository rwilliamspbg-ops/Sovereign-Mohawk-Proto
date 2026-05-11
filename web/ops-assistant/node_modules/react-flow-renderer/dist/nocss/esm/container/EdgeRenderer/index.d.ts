import React, { CSSProperties } from 'react';
import { Edge, ConnectionLineType, ConnectionLineComponent, OnEdgeUpdateFunc, HandleType, EdgeTypesWrapped } from '../../types';
interface EdgeRendererProps {
    edgeTypes: EdgeTypesWrapped;
    connectionLineType: ConnectionLineType;
    connectionLineStyle?: CSSProperties;
    connectionLineComponent?: ConnectionLineComponent;
    connectionLineContainerStyle?: CSSProperties;
    onEdgeClick?: (event: React.MouseEvent, node: Edge) => void;
    onEdgeDoubleClick?: (event: React.MouseEvent, edge: Edge) => void;
    defaultMarkerColor: string;
    onlyRenderVisibleElements: boolean;
    onEdgeUpdate?: OnEdgeUpdateFunc;
    onEdgeContextMenu?: (event: React.MouseEvent, edge: Edge) => void;
    onEdgeMouseEnter?: (event: React.MouseEvent, edge: Edge) => void;
    onEdgeMouseMove?: (event: React.MouseEvent, edge: Edge) => void;
    onEdgeMouseLeave?: (event: React.MouseEvent, edge: Edge) => void;
    onEdgeUpdateStart?: (event: React.MouseEvent, edge: Edge, handleType: HandleType) => void;
    onEdgeUpdateEnd?: (event: MouseEvent, edge: Edge, handleType: HandleType) => void;
    edgeUpdaterRadius?: number;
    noPanClassName?: string;
    elevateEdgesOnSelect: boolean;
    rfId?: string;
}
declare const _default: React.MemoExoticComponent<{
    (props: EdgeRendererProps): JSX.Element | null;
    displayName: string;
}>;
export default _default;
