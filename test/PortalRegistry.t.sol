// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { PortalRegistry } from "../src/PortalRegistry.sol";
import { CorrectModule } from "../src/example/CorrectModule.sol";
import { Portal } from "../src/types/Structs.sol";
import { Router } from "../src/Router.sol";
import { AttestationRegistryMock } from "./mocks/AttestationRegistryMock.sol";
import { ModuleRegistryMock } from "./mocks/ModuleRegistryMock.sol";
import { ValidPortalMock } from "./mocks/ValidPortalMock.sol";
import { InvalidPortalMock } from "./mocks/InvalidPortalMock.sol";

contract PortalRegistryTest is Test {
  address public user = makeAddr("user");
  Router public router;
  PortalRegistry public portalRegistry;
  address public moduleRegistryAddress;
  address public attestationRegistryAddress;
  string public expectedName = "Name";
  string public expectedDescription = "Description";
  string public expectedOwnerName = "Owner Name";
  ValidPortalMock public validPortalMock;
  InvalidPortalMock public invalidPortalMock = new InvalidPortalMock();

  event Initialized(uint8 version);
  event PortalRegistered(string name, string description, address portalAddress);

  function setUp() public {
    router = new Router();
    router.initialize();

    portalRegistry = new PortalRegistry();
    router.updatePortalRegistry(address(portalRegistry));

    moduleRegistryAddress = address(new ModuleRegistryMock());
    attestationRegistryAddress = address(new AttestationRegistryMock());
    vm.prank(address(0));
    portalRegistry.updateRouter(address(router));

    router.updateModuleRegistry(moduleRegistryAddress);
    router.updateAttestationRegistry(attestationRegistryAddress);
    vm.prank(address(0));
    portalRegistry.setIssuer(user);

    validPortalMock = new ValidPortalMock();
  }

  function test_alreadyInitialized() public {
    vm.expectRevert("Initializable: contract is already initialized");
    portalRegistry.initialize();
  }

  function test_updateRouter() public {
    PortalRegistry testPortalRegistry = new PortalRegistry();

    vm.prank(address(0));
    testPortalRegistry.updateRouter(address(1));
    address routerAddress = address(testPortalRegistry.router());
    assertEq(routerAddress, address(1));
  }

  function test_updateRouter_InvalidParameter() public {
    PortalRegistry testPortalRegistry = new PortalRegistry();

    vm.expectRevert(PortalRegistry.RouterInvalid.selector);
    vm.prank(address(0));
    testPortalRegistry.updateRouter(address(0));
  }

  function test_setIssuer_isIssuer_removeIssuer() public {
    vm.startPrank(address(0));
    address issuerAddress = makeAddr("Issuer");
    portalRegistry.setIssuer(issuerAddress);

    bool isIssuer = portalRegistry.isIssuer(issuerAddress);
    assertEq(isIssuer, true);

    portalRegistry.removeIssuer(issuerAddress);
    bool isIssuerAfterRemoval = portalRegistry.isIssuer(issuerAddress);
    assertEq(isIssuerAfterRemoval, false);
    vm.stopPrank();
  }

  function test_register() public {
    vm.expectEmit();
    emit PortalRegistered(expectedName, expectedDescription, address(validPortalMock));
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), expectedName, expectedDescription, true, expectedOwnerName);

    uint256 portalCount = portalRegistry.getPortalsCount();
    assertEq(portalCount, 1);

    Portal memory expectedPortal = Portal(
      address(validPortalMock),
      user,
      new address[](0),
      true,
      expectedName,
      expectedDescription,
      expectedOwnerName
    );

    Portal memory registeredPortal = portalRegistry.getPortalByAddress(address(validPortalMock));
    _assertPortal(registeredPortal, expectedPortal);
  }

  function test_register_OnlyIssuer() public {
    vm.expectRevert(PortalRegistry.OnlyIssuer.selector);
    vm.prank(makeAddr("InvalidIssuer"));
    portalRegistry.register(address(validPortalMock), expectedName, expectedDescription, true, expectedOwnerName);
  }

  function test_register_PortalAlreadyExists() public {
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), expectedName, expectedDescription, true, expectedOwnerName);
    vm.expectRevert(PortalRegistry.PortalAlreadyExists.selector);
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), expectedName, expectedDescription, true, expectedOwnerName);
  }

  function test_register_PortalAddressInvalid() public {
    vm.expectRevert(PortalRegistry.PortalAddressInvalid.selector);
    vm.prank(user);
    portalRegistry.register(address(0), expectedName, expectedDescription, true, expectedOwnerName);

    vm.expectRevert(PortalRegistry.PortalAddressInvalid.selector);
    vm.prank(user);
    portalRegistry.register(user, expectedName, expectedDescription, true, expectedOwnerName);
  }

  function test_register_PortalNameMissing() public {
    vm.expectRevert(PortalRegistry.PortalNameMissing.selector);
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), "", expectedDescription, true, expectedOwnerName);
  }

  function test_register_PortalDescriptionMissing() public {
    vm.expectRevert(PortalRegistry.PortalDescriptionMissing.selector);
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), expectedName, "", true, expectedOwnerName);
  }

  function test_register_PortalOwnerNameMissing() public {
    vm.expectRevert(PortalRegistry.PortalOwnerNameMissing.selector);
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), expectedName, expectedDescription, true, "");
  }

  function test_register_PortalInvalid() public {
    vm.expectRevert(PortalRegistry.PortalInvalid.selector);
    vm.prank(user);
    portalRegistry.register(address(invalidPortalMock), expectedName, expectedDescription, true, expectedOwnerName);
  }

  function test_deployDefaultPortal() public {
    CorrectModule correctModule = new CorrectModule();
    address[] memory modules = new address[](1);
    modules[0] = address(correctModule);
    vm.prank(user);
    portalRegistry.deployDefaultPortal(modules, expectedName, expectedDescription, true, expectedOwnerName);
  }

  function test_deployDefaultPortal_OnlyIssuer() public {
    CorrectModule correctModule = new CorrectModule();
    address[] memory modules = new address[](1);
    modules[0] = address(correctModule);
    vm.expectRevert(PortalRegistry.OnlyIssuer.selector);
    vm.prank(makeAddr("InvalidIssuer"));
    portalRegistry.deployDefaultPortal(modules, expectedName, expectedDescription, true, expectedOwnerName);
  }

  function test_getPortals_PortalNotRegistered() public {
    vm.expectRevert(PortalRegistry.PortalNotRegistered.selector);
    portalRegistry.getPortalByAddress(address(validPortalMock));
  }

  function test_isRegistered() public {
    assertEq(portalRegistry.isRegistered(address(validPortalMock)), false);
    vm.prank(user);
    portalRegistry.register(address(validPortalMock), expectedName, expectedDescription, true, expectedOwnerName);
    assertEq(portalRegistry.isRegistered(address(validPortalMock)), true);
  }

  function _assertPortal(Portal memory portal1, Portal memory portal2) internal {
    assertEq(portal1.name, portal2.name);
    assertEq(portal1.description, portal2.description);
    assertEq(portal1.isRevocable, portal2.isRevocable);
    assertEq(portal1.ownerAddress, portal2.ownerAddress);
    assertEq(portal1.ownerName, portal2.ownerName);
  }
}
