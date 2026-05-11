import { RefObject } from 'react';
import { CoordinateExtent, Node, NodeDragItem, NodeInternals, XYPosition } from '../../types';
export declare function isParentSelected(node: Node, nodeInternals: NodeInternals): boolean;
export declare function hasSelector(target: Element, selector: string, nodeRef: RefObject<Element>): boolean;
export declare function getDragItems(nodeInternals: NodeInternals, mousePos: XYPosition, nodeId?: string): NodeDragItem[];
export declare function updatePosition(dragItem: NodeDragItem, mousePos: XYPosition, snapToGrid: boolean, [snapX, snapY]: [number, number], nodeInternals: NodeInternals, nodeExtent?: CoordinateExtent): NodeDragItem;
export declare function getEventHandlerParams({ nodeId, dragItems, nodeInternals, }: {
    nodeId?: string;
    dragItems: NodeDragItem[];
    nodeInternals: NodeInternals;
}): [Node, Node[]];
