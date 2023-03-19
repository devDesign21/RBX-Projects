local fps = {};
local fps_mt = {__index = fps};

local camera = game.Workspace.CurrentCamera;
local physicsService = game:GetService("PhysicsService");
local runService = game:GetService("RunService");
local inputService = game:GetService("UserInputService");

local modules = game.ReplicatedStorage:WaitForChild("Modules");
local remotes = game.ReplicatedStorage:WaitForChild("Remotes");
local spring = require(modules:WaitForChild("spring"));
local createRig = require(modules:WaitForChild("createRig"));
local studioAnim = require(modules:WaitForChild("studioAnim"));
local vector = require(modules:WaitForChild("vector")); -- never ended up using this

local WeaponModule = require(game.Workspace:WaitForChild("WeaponModule"))

local isServer = remotes.isServer:InvokeServer();

loadAnimation = false

-- private functions

local function setCollisionGroupRecursive(children, group)
	for i = 1, #children do
		if (children[i]:IsA("BasePart")) then
			physicsService:SetPartCollisionGroup(children[i], group);
		end
		setCollisionGroupRecursive(children[i]:GetChildren(), group)
	end
end

local function init(self)
	self.joint = Instance.new("Motor6D");
	self.joint.Part0 = self.viewModel.Head;
	self.joint.Parent = self.viewModel.Head;

	if (self.isR15) then
		local lookAround = self.humanoid.Parent:WaitForChild("Animate"):WaitForChild("idle"):FindFirstChild("Animation2");
		if (lookAround) then lookAround:Destroy(); end
	end

	self.humanoid.Died:Connect(function()
		self.isAlive = false;
		self:unequip();

		self.crouchTrack:Destroy()
		self.proneTrack:Destroy()
		self.charSprintingTrack:Destroy()
		self.standingTrack:Destroy()
		loadAnimation = false
	end);

	setCollisionGroupRecursive(self.viewModel:GetChildren(), "viewModel");
end

local function updateArm(self, key)
	if (self[key]) then
		local shoulder = self.isR15 and self.viewModel[key.."UpperArm"][key.."Shoulder"] or self.viewModel.Torso[key .. " Shoulder"];
		local cf = self.weapon[key].CFrame * CFrame.Angles(math.pi/2, 0, 0) * CFrame.new(0, self.isR15 and 1.5 or 1, 0);
		shoulder.C1 = cf:inverse() * shoulder.Part0.CFrame * shoulder.C0;
	end
end


function fps.new(character)
	local self = {};

	self.viewModel = createRig(character);	
	self.humanoid = character:WaitForChild("Humanoid");
	self.hrp = character:WaitForChild("HumanoidRootPart");

	self.isAiming = false;
	self.isEquipped = false;
	self.isAlive = self.humanoid.Health > 0;
	self.isR15 = self.humanoid.RigType == Enum.HumanoidRigType.R15;

	self.baseFOV = 70

	local fovAim = 24
	self.aimLerp = spring.new(0, 0, 0, fovAim, 1);
	self.armTilt = spring.new(0, 0, 0, 30, 1);
	self.FOV = spring.new(self.baseFOV, 0, self.baseFOV, fovAim, 1);
	self.sway = spring.new(Vector3.new(), Vector3.new(), Vector3.new(), 85, 1);
	self.recoil = spring.new(Vector3.new(), Vector3.new(), Vector3.new(), 40, 1);
	self.bobbing = spring.new(Vector3.new(), Vector3.new(), Vector3.new(), 15, 1);
	self.crouchLerp = spring.new(0, 0, 0, 15, 1);

	init(self);
	return setmetatable(self, fps_mt);
end



function fps:updateSway(x, y)
	if (self.settings.CAN_SWAY) then
		self.sway.target = Vector3.new(math.rad(x), math.rad(y), 0);
	end
end

function fps:Reload(reloadTime)



	local speed = self.reloadTrack.Length / (reloadTime+0.08)

	self.reloadTrack:Play(0.4,1,speed)

end

function fps:updateClient(dt, GUI)
	if (self.isEquipped and self.isAlive) then
		GUI.Crosshair.Main.Center.Transparency = self.aimLerp.p
		GUI.Crosshair.Main.HL.Transparency = self.aimLerp.p 
		GUI.Crosshair.Main.HR.Transparency = self.aimLerp.p
		GUI.Crosshair.Main.VD.Transparency = self.aimLerp.p
		GUI.Crosshair.Main.VU.Transparency = self.aimLerp.p


		local moveDirection = self.humanoid.moveDirection;
		local isMoving = moveDirection:Dot(moveDirection) > 0;
		local modifier = (self.isAiming and self.settings.ADS_BOB_MODIFIER or 1) * 0.05;
		local strafe = -self.hrp.CFrame.rightVector:Dot(moveDirection);
		local recoilMod = self.isAiming and 1/3 or 1;


		local speed = self.humanoid.WalkSpeed / 12.5;
		self.bobbing.target = isMoving and Vector3.new(math.sin(tick()*7*speed)*modifier, math.sin(tick()*10*speed)*modifier, 0) or Vector3.new();
		self.armTilt.target = math.rad((self.isAiming and self.settings.TILT_AIMED or self.settings.TILT_HOLD) * strafe);

		self.FOV:update(dt);
		self.sway:update(dt);
		self.recoil:update(dt);
		self.aimLerp:update(dt);
		self.armTilt:update(dt);
		self.bobbing:update(dt);
		self.crouchLerp:update(dt);


		--		self.joint.C0 = self.settings.CAMERA_OFFSET * CFrame.new(self.bobbing.p) * CFrame.new(0, 0, recoilMod*self.recoil.p.x) * CFrame.fromEulerAnglesYXZ(0, 0, self.armTilt.p);
		--		self.joint.C1 = CFrame.new():lerp(self.aimCFrame, self.aimLerp.p);
		--		
		--		camera.FieldOfView = self.FOV.p;
		--		camera.CFrame = camera.CFrame * CFrame.fromEulerAnglesYXZ(self.recoil.p.y, self.recoil.p.z, 0)
		--		self.viewModel.Head.CFrame = camera.CFrame * CFrame.Angles(self.sway.p.y, self.sway.p.x, 0);



		self.joint.C0 = self.settings.CAMERA_OFFSET * CFrame.new(self.bobbing.p) * CFrame.new(0, 0, recoilMod*self.recoil.p.x) * CFrame.fromEulerAnglesYXZ(0, 0, self.armTilt.p);
	
		camera.FieldOfView = self.FOV.p;
		camera.CFrame = camera.CFrame * CFrame.fromEulerAnglesYXZ(self.recoil.p.y, self.recoil.p.z, 0)
		self.viewModel.HumanoidRootPart.CFrame = camera.CFrame* self.settings.CAMERA_OFFSET * CFrame.Angles(self.sway.p.y, self.sway.p.x, 0) * CFrame.new(self.bobbing.p)* CFrame.new(0, 0, recoilMod*self.recoil.p.x) * CFrame.fromEulerAnglesYXZ(0, 0, self.armTilt.p);
		self.viewModel.Weapon.AimPart.CFrame = (self.viewModel.Weapon.AimPart.CFrame):lerp(camera.CFrame*CFrame.new(0,0,WeaponModule()[self.viewModel.WeaponName.Value]["AimOffset"])* CFrame.Angles(self.sway.p.y, self.sway.p.x, 0) * CFrame.new(self.bobbing.p)* CFrame.new(0, 0, recoilMod*self.recoil.p.x) * CFrame.fromEulerAnglesYXZ(0, 0, self.armTilt.p), self.aimLerp.p); -- 


		self.humanoid.Parent.Humanoid.CameraOffset = Vector3.new(0, 0, -0):lerp(Vector3.new(0, -3, -0), self.crouchLerp.p);

		--		updateArm(self, "Right");
		--		updateArm(self, "Left");



	end
end



function fps:aimDownSights(isAiming)
	self.isAiming = isAiming;



	if (self.isEquipped and self.isAlive) then

		inputService.MouseIconEnabled = false --not isAiming;

		self.aimLerp.target = isAiming and 1 or 0;
		self.FOV.target = isAiming and self.settings.AIM_FOV or self.baseFOV;

	end
end

function fps:fire()
	if (self.isEquipped and self.isAlive) then

		if self.isAiming == false then
			self.recoil.p = self.settings.recoilFunc(WeaponModule()[self.viewModel.WeaponName.Value]["recoilKick"]);
		else
			self.recoil.p = self.settings.recoilFunc(WeaponModule()[self.viewModel.WeaponName.Value]["recoilKickADS"]);
		end
	end
end

local PhysicsService = game:GetService("PhysicsService")
local function RecursiveSetCollsionGroup(Children, Group)
	for Index = 1, #Children do
		if (Children[Index]:IsA("BasePart")) then
			PhysicsService:SetPartCollisionGroup(Children[Index], Group)
		end
		RecursiveSetCollsionGroup(Children[Index]:GetChildren(), Group)
	end
end


function fps:equip(weaponName, typeEquipped, action, secondary, bodyMode)
	if (not weaponName) then 
		self:unequip();
		return;
	end 

	local ViewModel = game:GetService("ReplicatedStorage").Weapons:WaitForChild(weaponName):Clone()

	ViewModel.Name = "ViewModel"



	self.weapon = ViewModel.Weapon
	self.settings = require(self.weapon:WaitForChild("settings"))(self.isR15);
	self.viewModel = ViewModel

	local leftHand = game.Lighting.Arm:Clone()
	leftHand.Name = "leftHand"
	leftHand.Parent = ViewModel
	leftHand:SetPrimaryPartCFrame(ViewModel.LeftHand.CFrame)		
	local weld = Instance.new('Weld', ViewModel.LeftHand)
	weld.Part0 = ViewModel.LeftHand
	weld.Part1 = leftHand.UpperHand

	local rightHand = game.Lighting.Arm:Clone()
	rightHand.Name = "rightHand"
	rightHand.Parent = ViewModel
	rightHand:SetPrimaryPartCFrame(ViewModel.RightHand.CFrame)		
	local weld = Instance.new('Weld', ViewModel.RightHand)
	weld.Part0 = ViewModel.RightHand
	weld.Part1 = rightHand.UpperHand

	self.viewModel.LeftHand.Transparency = 1
	self.viewModel.LeftLowerArm.Transparency = 1
	self.viewModel.LeftUpperArm.Transparency = 1

	self.viewModel.RightHand.Transparency = 1
	self.viewModel.RightLowerArm.Transparency = 1
	self.viewModel.RightUpperArm.Transparency = 1




	ViewModel.Parent = game.Workspace.CurrentCamera



	remotes.setup:FireServer(self.isR15, weaponName, typeEquipped, action, secondary);


	self.isSprinting = false
	self.isWalking = false

	self.bodyMode = bodyMode




	self.aimCFrame =  self.settings.CAMERA_OFFSET * self.weapon.frame.CFrame:inverse() * self.weapon.AimPart.CFrame;


	self.viewModel.LeftHand.Size = Vector3.new(0.5, 0.315, 0.5)
	self.viewModel.LeftLowerArm.Size = Vector3.new(0.5, 1.105, 0.5)
	self.viewModel.LeftUpperArm.Size = Vector3.new(0.5, 1.227, 0.50)

	self.viewModel.RightHand.Size = Vector3.new(0.5, 0.315, 0.55)
	self.viewModel.RightLowerArm.Size = Vector3.new(0.501, 1.105, 0.501)
	self.viewModel.RightUpperArm.Size = Vector3.new(0.5, 1.227, 0.5)



	if loadAnimation == false then
		loadAnimation = true
		print("TRUEE LOADANIMATION!!!!!!!!!!")
		local animation = Instance.new("Animation")
		animation.AnimationId = "http://www.roblox.com/asset/?id=4649655599"	
		self.crouchTrack = self.humanoid:LoadAnimation(animation)

		local animation = Instance.new("Animation")
		animation.AnimationId = "http://www.roblox.com/asset/?id=4945110065"	
		self.proneTrack = self.humanoid:LoadAnimation(animation)



		local animation = Instance.new("Animation")
		animation.AnimationId = "http://www.roblox.com/asset/?id=4945331799"
		self.standingTrack = self.humanoid:LoadAnimation(animation)

		local animation = Instance.new("Animation")
		animation.AnimationId = "http://www.roblox.com/asset/?id=4948273926"	
		self.charSprintingTrack = self.humanoid:LoadAnimation(animation)

		self.standingTrack:Play()
		self.crouchLerp.target = 0
	end

	local Anim = Instance.new("Animation")
	Anim.AnimationId = "http://www.roblox.com/asset/?id="..WeaponModule()[self.viewModel.WeaponName.Value]["idleAnim"]
	self.idleTrack = ViewModel.Humanoid:LoadAnimation(Anim)


	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id="..WeaponModule()[self.viewModel.WeaponName.Value]["reloadAnim"]
	self.reloadTrack = self.viewModel.Humanoid:LoadAnimation(animation)

	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id=4927542300"	
	self.adsTrack = self.viewModel.Humanoid:LoadAnimation(animation)

	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id="..WeaponModule()[self.viewModel.WeaponName.Value]["equipAnim"]		
	self.equipTrack = self.viewModel.Humanoid:LoadAnimation(animation)

	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id="..WeaponModule()[self.viewModel.WeaponName.Value]["sprintAnim"]	
	self.sprintTrack = self.viewModel.Humanoid:LoadAnimation(animation)

	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id=4931211114"	
	self.stopSprintTrack = self.viewModel.Humanoid:LoadAnimation(animation)

	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id="..WeaponModule()[self.viewModel.WeaponName.Value]["fireAnim"]	
	self.fireTrack = self.viewModel.Humanoid:LoadAnimation(animation)

	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id="..WeaponModule()[self.viewModel.WeaponName.Value]["unEquipAnim"]	
	self.unEquipTrack = self.viewModel.Humanoid:LoadAnimation(animation)



	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id=4944456245"	
	self.viewModelCrouch = self.viewModel.Humanoid:LoadAnimation(animation)




	RecursiveSetCollsionGroup(ViewModel:GetChildren(), "ViewModel")
	self.isEquipped = true;


	self.equipTrack:Play()
	wait(0.12)
	leftHand.Arm.Transparency = 0
	leftHand.Arm2.Transparency = 0
	leftHand.LowerBlack.Transparency = 0
	leftHand.UpperHand.Transparency = 0

	rightHand.Arm.Transparency = 0
	rightHand.Arm2.Transparency = 0
	rightHand.LowerBlack.Transparency = 0
	rightHand.UpperHand.Transparency = 0

	self.idleTrack:Play(0.1) 
	self.equipTrack:Stop(0.1)

	RecursiveSetCollsionGroup(ViewModel:GetChildren(), "ViewModel")


end

function fps:Walking(inputState)
	self.isWalking = inputState
end

function fps:Crouch(inputState, bodyMode, action)


end

local movementDebounce = false

function fps:Boost()
	self.humanoid.WalkSpeed = 40
	wait(0.15)
	self.humanoid.WalkSpeed = 30
	wait(0.12)
	self.humanoid.WalkSpeed = 20
	wait(0.07)
	self.humanoid.WalkSpeed = 10
	wait(0.05)
	self.humanoid.WalkSpeed = 5

end

function fps:Movement(bodyMode, animationBool, walkspeedBool, action)

	if movementDebounce == false  and self.isAlive == true then
		self.bodyMode = bodyMode
	
		if bodyMode == "standing" then
			if animationBool == true then
				self.sprintTrack:Stop(0.12)
			end

			self.crouchTrack:Stop()
			self.proneTrack:Stop()
			self.charSprintingTrack:Stop(.35)
			self.standingTrack:Play(.35)



			self.crouchLerp.target = 0


			if walkspeedBool == true then
				self.humanoid.WalkSpeed = 15
				if self.isAiming == true then
					self.humanoid.WalkSpeed = 5
				end
			end
		elseif bodyMode == "sprinting" then
			if animationBool == true then
				self.sprintTrack:Play()

			end

			self.crouchTrack:Stop()
			self.proneTrack:Stop()
			self.standingTrack:Stop()
			self.charSprintingTrack:Play()


			self.crouchLerp.target = 0
			if walkspeedBool == true then
				self.humanoid.WalkSpeed = 22
				if self.isAiming == true then
					self.humanoid.WalkSpeed = 7
					--self.sprintTrack:Stop()
				end
			end



		elseif bodyMode == "crouch" then
			if animationBool == true then
				self.sprintTrack:Stop()

			end

			self.proneTrack:Stop()
			self.standingTrack:Stop()
			self.crouchTrack:Play()

			self.charSprintingTrack:Stop()

			self.crouchLerp.target = 0.4
			if walkspeedBool == true then
				self.humanoid.WalkSpeed = 5
			end

			if action == "boost" then


				self.humanoid.WalkSpeed = 40
				wait(0.23)
				self.humanoid.WalkSpeed = 30
				wait(0.12)
				self.humanoid.WalkSpeed = 20
				wait(0.07)
				self.humanoid.WalkSpeed = 15
				wait(0.05)
				self.humanoid.WalkSpeed = 8
				wait(0.04)
				self.humanoid.WalkSpeed = 6
				wait(0.02)
			
			end
		elseif bodyMode == "prone" then
			if animationBool == true then
				self.sprintTrack:Stop(0.3)
			end
			self.crouchTrack:Stop()
			self.standingTrack:Stop()
			
			self.charSprintingTrack:Stop()
			self.proneTrack:Play()



			self.crouchLerp.target = 1

			if action == "boost" then


				self.humanoid.WalkSpeed = 40
				wait(0.17)
				self.humanoid.WalkSpeed = 30
				wait(0.07)
				self.humanoid.WalkSpeed = 20
				wait(0.07)
				self.humanoid.WalkSpeed = 15
				wait(0.05)
				self.humanoid.WalkSpeed = 8
				wait(0.04)
				self.humanoid.WalkSpeed = 6
				wait(0.02)
			
			end


			if walkspeedBool == true then
				self.humanoid.WalkSpeed = 4
				--wait(1)
			end

		end


	end

	if  action == "aim" and bodyMode ~= "crouch" and bodyMode ~= "prone" then
		if (bodyMode == "standing" or bodyMode == "sprinting") then	

			self.charSprintingTrack:Stop()
			self.standingTrack:Play()
		else

			self.charSprintingTrack:Play()
		end
	end

	if action == "reload" then
		self.charSprintingTrack:Stop(.25)
		self.sprintTrack:Stop(.22)
		--self.standingTrack:Play(.25)
		reloadTime = 2.5
		local speed = self.reloadTrack.Length / (reloadTime+0.08)
		--print(speed)
		--self.reloadTrack:AdjustSpeed(0.01)
		--wait(0.23)
		self.reloadTrack:Play(.22,1,speed)
	end



	movementDebounce = false
	--end
end
function fps:updateServer(dt)
	if (self.isEquipped and self.isAlive) then
		--print(self.bodyMode)
		if self.bodyMode == "prone" then
			--print("CLAMPINGGG")
			local theta = camera.CFrame.LookVector.y
			theta = math.clamp(math.asin(camera.CFrame.LookVector.y),-0.3,1)

			remotes.tiltAt:FireServer(theta)
		else
			remotes.tiltAt:FireServer(math.asin(camera.CFrame.LookVector.y));
		end
	end
end

function fps:Sprint(inputState, animationBool, walkSpeedBool)

	if (inputState == Enum.UserInputState.Begin) and self.isAiming == false  then
		--self.idleTrack:Stop()
		--debounce = true
		--self.idleTrack:Stop()
		--if animationBool == true then
		self.sprintTrack:Play(0.15)
		--end

		--if walkSpeedBool == true then
		self.humanoid.WalkSpeed = 22
		--end


		self.isSprinting = true
		--self.bobbing = spring.new(Vector3.new(), Vector3.new(), Vector3.new(), 27, 0.5);


	elseif (inputState == Enum.UserInputState.End) and self.bodyMode == "standing"  then
		--debounce = true
		if self.isAiming == true then

		elseif self.isAiming == false then
			self.humanoid.WalkSpeed = 12.5
		end


		self.isSprinting = false
		self.idleTrack:Play(0.12)
		self.sprintTrack:Stop(0.12)





	end
end

--function fps:sprint()
--	self.humanoid.WalkSpeed = 40
--end

function fps:unequip()

	self.FOV.target =  self.baseFOV;

	self.unEquipTrack:Play(0.07)
	wait(0.14)
	self.isEquipped = false;

	remotes.cleanup:FireServer();



	if (self.weapon) then self.weapon:Destroy(); end
	if (self.lastAnim) then self.lastAnim:Stop(); end
	if (self.FireSound) then self.FireSound:Destroy(); end
	if game.Workspace.CurrentCamera:FindFirstChild("ViewModel") then game.Workspace.CurrentCamera:FindFirstChild("ViewModel"):Destroy(); end

	--	self.isSprinting = false;
	self.viewModel.Parent = nil;
	--	self.humanoid.WalkSpeed = self.baseWalkSpeed;


end

--

return fps;
